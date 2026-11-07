#!/usr/bin/env python3
"""Exercise the real Archi CLI in an image. Requires Docker and Python 3 only."""
import argparse
import csv
from pathlib import Path
import re
import shutil
import subprocess
import uuid
import xml.etree.ElementTree as ET
import zipfile
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]


def check(condition, message):
    if not condition:
        raise AssertionError(message)


def git(*args):
    return subprocess.check_output(['git', *map(str, args)], text=True).strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('image')
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--rootless', action='store_true')
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)

    def run(case, env=None, cli=(), bad=False, setup=None):
        work = output / case
        work.mkdir()
        shutil.copytree(ROOT / 'tests/fixtures/coarchi', work / 'model repo')
        # Git receive-pack clears GIT_CONFIG_COUNT for local transports. A real
        # global config is inherited by the child handling the bare test remote.
        (work / 'gitconfig').write_text('[safe]\n\tdirectory = /work/remote.git\n')
        if setup:
            setup(work)
        for path in [work, *work.rglob('*')]:
            path.chmod(0o777 if path.is_dir() else 0o666)
        name = 'archimate-test-' + uuid.uuid4().hex
        command = ['docker', 'run', '--rm', '--name', name, '--network', 'none',
                   '-v', f'{work}:/work', '-e', 'ARCHI_PROJECT_PATH=/work/model repo',
                   '-e', 'ARCHI_REPORT_PATH=/work/report']
        for key, value in (env or {}).items():
            command += ['-e', f'{key}={value}']
        command += [args.image, *cli]
        print(f'{args.image}: {case}', flush=True)
        with (output / f'{case}.log').open('w') as log:
            try:
                result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=180)
            finally:
                subprocess.run(['docker', 'rm', '-f', name], stdout=subprocess.DEVNULL,
                               stderr=subprocess.DEVNULL, timeout=30)
        check((result.returncode != 0) if bad else (result.returncode == 0),
              f'{case}: unexpected exit code {result.returncode}; see {output / (case + ".log")}')
        return work

    def model(path):
        root = ET.parse(path).getroot()
        ids = {node.get('id'): node for node in root.iter() if node.get('id')}
        check({'ci-app', 'ci-service', 'ci-relation', 'ci-view'} <= ids.keys(), 'Missing model content')
        check(ids['ci-app'].get('name') == 'Приложение', 'Cyrillic element name lost')
        check('Тестовая документация' in path.read_text(), 'Documentation lost')
        check('Команда' in path.read_text(), 'Property lost')

    def html(path, expected=()):
        text = path.read_text()
        check('CI Model' in text, 'HTML model title missing')
        for label in expected:
            matches = re.findall(r'<a href="([^"]+)" class="go">' + label + r'</a>', text)
            check(len(matches) == 1, f'Missing/duplicate {label} link')
            check((path.parent / unquote(matches[0])).is_file(), f'Broken {label} link')
        check(any(p.stat().st_size > 100 for p in path.parent.rglob('*.png')), 'Diagram image missing')
        check(any('Приложение' in p.read_text() for p in path.parent.rglob('*.html')), 'HTML content missing')

    def exports(path, html_path=None, delimiter=','):
        model(path / 'CI Model.archimate')
        with (path / 'elements.csv').open(encoding='utf-8-sig', newline='') as file:
            rows = list(csv.DictReader(file, delimiter=delimiter))
        check({row['ID'] for row in rows} == {'ci-model', 'ci-app', 'ci-service'}, 'CSV model/elements missing')
        check('Приложение' in (path / 'elements.csv').read_text(), 'CSV Cyrillic lost')
        with (path / 'relations.csv').open(encoding='utf-8-sig', newline='') as file:
            check(len(list(csv.DictReader(file, delimiter=delimiter))) == 1, 'Expected one relationship')
        check('Команда' in (path / 'properties.csv').read_text(), 'CSV property lost')
        check((path / 'CI Model.pdf').read_bytes().startswith(b'%PDF-'), 'Invalid PDF')
        with zipfile.ZipFile(path / 'CI Model.docx') as doc:
            check('word/document.xml' in doc.namelist(), 'Invalid DOCX')
        if html_path:
            html(html_path, ['Elements', 'Properties', 'Relations', 'PDF', 'DOCX', 'Model'])

    run('help', cli=('--help',))
    help_text = (output / 'help.log').read_text()
    check('--modelrepository.loadModel' in help_text, 'coArchi CLI missing')
    check('--html.createReport' in help_text, 'HTML CLI missing')
    runtime = subprocess.check_output(['docker', 'run', '--rm', '--entrypoint', 'sh', args.image, '-c',
        'cat /opt/Archi/configuration/org.eclipse.equinox.simpleconfigurator/bundles.info; find "$HOME/.archi/dropins" -name "*0.9.8*"'], text=True)
    check('5.10.0' in runtime and '0.9.8' in runtime, 'Unexpected installed Archi/coArchi version')
    identity = subprocess.check_output(['docker', 'run', '--rm', '--entrypoint', 'id', args.image, '-u'], text=True).strip()
    check(identity != '0' if args.rootless else identity == '0', 'Wrong container UID')
    default = run('defaults')
    model(default / 'report/CI Model.archimate')
    html(default / 'report/html/index.html', ['Model'])
    all_env = {'ARCHI_CSV_REPORT_ENABLED': 'true', 'ARCHI_JASPER_REPORT_ENABLED': 'true',
               'ARCHI_HTML_REPORT_PATH': '/work/exports with spaces',
               'ARCHI_CSV_REPORT_PATH': '/work/exports with spaces',
               'ARCHI_JASPER_REPORT_PATH': '/work/exports with spaces',
               'ARCHI_EXPORT_MODEL_PATH': '/work/exports with spaces',
               'ARCHI_EXTRA_ARGS': '--csv.exportDelimiter ;'}
    full = run('all-exports', all_env)
    exports(full / 'exports with spaces', full / 'exports with spaces/index.html', delimiter=';')
    run('html-disabled', {'ARCHI_HTML_REPORT_ENABLED': 'false', 'ARCHI_CSV_REPORT_ENABLED': 'true'})
    model(output / 'html-disabled/report/CI Model.archimate')
    check((output / 'html-disabled/report/csv/elements.csv').is_file(), 'CSV missing with HTML disabled')

    def corrupt(work):
        (work / 'model repo/model/application/ApplicationComponent_ci-app.xml').write_text('<broken')
    run('invalid-model', bad=True, setup=corrupt)
    run('invalid-cli', cli=('--loadModel', '/does-not-exist.archimate'), bad=True)
    run('invalid-export', {'ARCHI_HTML_REPORT_PATH': '/proc/archimate-report'}, bad=True)

    def cli_model(work):
        shutil.copyfile(default / 'report/CI Model.archimate', work / 'input.archimate')
    direct = run('custom-cli', cli=('--loadModel', '/work/input.archimate', '--saveModel', '/work/direct.archimate'), setup=cli_model)
    model(direct / 'direct.archimate')

    split = run('split-exports', {'ARCHI_CSV_REPORT_ENABLED': 'true', 'ARCHI_JASPER_REPORT_ENABLED': 'true',
                                 'ARCHI_HTML_REPORT_PATH': '/work/html report',
                                 'ARCHI_CSV_REPORT_PATH': '/work/csv export',
                                 'ARCHI_JASPER_REPORT_PATH': '/work/jasper export',
                                 'ARCHI_EXPORT_MODEL_PATH': '/work/model export'})
    html(split / 'html report/index.html', ['Elements', 'Properties', 'Relations', 'PDF', 'DOCX', 'Model'])
    model(split / 'model export/CI Model.archimate')

    def initialize(work):
        repo = work / 'model repo'
        git('init', '-b', 'main', repo)
        git('-C', repo, 'config', 'user.name', 'CI Test')
        git('-C', repo, 'config', 'user.email', 'ci@example.invalid')
        git('-C', repo, 'add', '.')
        git('-C', repo, 'commit', '-m', 'Fixture')
        git('init', '--bare', work / 'remote.git')
        git('-C', repo, 'remote', 'add', 'origin', '/work/remote.git')

    gha_env = {'GITHUB_ACTIONS': 'true', 'GITHUB_REPOSITORY': 'test/model', 'GITHUB_REF_NAME': 'main',
               'GITHUB_TOKEN': 'test-dummy-token', 'GITHUB_ACTOR': 'ci-test',
               # The bare test remote is bind-mounted from a different host UID.
               'GIT_CONFIG_GLOBAL': '/work/gitconfig',
               'ARCHI_CSV_REPORT_ENABLED': 'true', 'ARCHI_JASPER_REPORT_ENABLED': 'true'}
    gha = run('github-actions', gha_env, setup=initialize)
    exports(gha / 'model repo/.archi_report', gha / 'model repo/.archi_report/index.html')
    check('index.html' in git('--git-dir', gha / 'remote.git', 'ls-tree', '--name-only', 'gh-pages'), 'Pages push failed')
    check('test-dummy-token' not in (output / 'github-actions.log').read_text(), 'Token leaked')

    def repeat(work):
        shutil.rmtree(work / 'model repo')
        shutil.copytree(gha / 'model repo', work / 'model repo')
        git('init', '--bare', work / 'remote.git')
    repeated = run('github-actions-repeat', gha_env, setup=repeat)
    exports(repeated / 'model repo/.archi_report', repeated / 'model repo/.archi_report/index.html')
    gl = run('gitlab-ci', {'GITLAB_CI': 'true', 'CI_PROJECT_DIR': '/work/model repo',
                           'ARCHI_CSV_REPORT_ENABLED': 'true', 'ARCHI_JASPER_REPORT_ENABLED': 'true'})
    exports(gl / 'model repo/public', gl / 'model repo/public/index.html')

    def rename(work):
        folder = work / 'model repo/model/folder.xml'
        folder.write_text(folder.read_text().replace('CI Model', 'Модель тест'))
    unicode_model = run('unicode-name', setup=rename)
    model(unicode_model / 'report/Модель тест.archimate')
    page = unicode_model / 'report/html/index.html'
    href = re.search(r'<a href="([^"]+)" class="go">Model</a>', page.read_text())[1]
    check((page.parent / unquote(href)).is_file(), 'Non-ASCII model download link broken')
    print(f'PASS: {args.image}', flush=True)


if __name__ == '__main__':
    main()
