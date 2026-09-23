#!/usr/bin/env python3
"""Wrapper contracts only; native ARM qualification belongs to CI."""
import io
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
from unittest.mock import patch

wrapper = Path(__file__).with_name('ci-compare')
class Stream:
    def __init__(self, data=b''):
        self.buffer = io.BytesIO(data)

class Log(io.StringIO):
    def __exit__(self, *args):
        return False

for reference, expected in [((1, b'json', b''), 1),
                            ((0, b'json', b''), 'mismatch'),
                            ((1, b'other', b''), 'mismatch'),
                            ((1, b'json', b'error'), 'mismatch')]:
    output, errors, log = Stream(), Stream(), Log()
    results = [subprocess.CompletedProcess([], 1, b'json', b''),
               subprocess.CompletedProcess([], *reference)]
    with patch.object(sys, 'argv', [str(wrapper), '--norc', '-']), \
         patch.object(sys, 'stdin', Stream(b'echo $x\n')), \
         patch.object(sys, 'stdout', output), patch.object(sys, 'stderr', errors), \
         patch.dict(os.environ, {'ARMV6_COMPARISON_LOG': 'contract.jsonl'}), \
         patch('builtins.open', return_value=log), \
         patch('subprocess.run', side_effect=results) as run:
        try:
            runpy.run_path(str(wrapper), run_name='__main__')
        except SystemExit as exit_status:
            if expected == 'mismatch':
                assert 'mismatch' in exit_status.code
            else:
                assert exit_status.code == expected
        else:
            raise AssertionError('missing status propagation')
    assert len(run.call_args_list) == 2
    assert all(call.kwargs['input'] == b'echo $x\n' for call in run.call_args_list)
    assert all(call.args[0][:3] == ['qemu-arm-static', '-cpu', 'arm1176'] for call in run.call_args_list)
    record = json.loads(log.getvalue())
    assert record['equal'] == (expected != 'mismatch')
    if record['equal']:
        assert output.buffer.getvalue() == b'json'
    else:
        assert record['outputs'] and record['stdin_b64']
print('PASS four byte-exact comparison/status/evidence wrapper contracts')
