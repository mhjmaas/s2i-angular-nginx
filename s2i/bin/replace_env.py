import os
import fileinput
from tempfile import mkstemp
from shutil import move
from os import fdopen, remove

var_mask = "env_"
for key in os.environ.keys():
    if key.lower().startswith(var_mask):
        file_path = "/etc/nginx/conf.d/module.conf"

        #Create temp file
        fh, abs_path = mkstemp()
        with fdopen(fh,'w') as new_file:
            with open(file_path) as old_file:
                for line in old_file:
                    new_file.write(line.replace("${"+key+"}", os.environ[key]))
        #Remove original file
        remove(file_path)
        #Move new file
        move(abs_path, file_path)