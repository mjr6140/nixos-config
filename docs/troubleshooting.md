# Troubleshooting Notes

## QIDI Studio crashes after adding a network printer

If QIDI Studio starts, connects to a printer, then exits with `No such file or
directory` and status `139`, check whether it persisted the network printer as
the last selected machine.

The setting lives outside this repo:

```sh
rg -n 'last_selected_machine|10\.12\.1\.153|10088' ~/.config/QIDIStudio/QIDIStudio.conf
```

Workaround:

```sh
perl -0pi -e 's/"last_selected_machine": "10\.12\.1\.153"/"last_selected_machine": ""/' ~/.config/QIDIStudio/QIDIStudio.conf
```

The issue was reproduced after adding the X-Plus 3 at `10.12.1.153:10088`.
Clearing `last_selected_machine` allowed QIDI Studio to start normally again.
