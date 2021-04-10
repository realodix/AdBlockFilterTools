#!/bin/bash

find . -type d -name '__pycache__' -exec rm -r {} +
git diff --no-index --histogram -D -- python-abp/abp python-abp_AdBlockID/abp > python-abp_AdBlockID/_diff/python-abp.patch
git diff --no-index --histogram -D -- python-abp/README.rst python-abp_AdBlockID/README.rst > python-abp_AdBlockID/_diff/README.rst.patch
git diff --no-index --histogram -D -- python-abp/setup.py python-abp_AdBlockID/setup.py > python-abp_AdBlockID/_diff/setup.py.patch

git diff --no-index --histogram -- FOP_RuAdList/fop.py FOP_AdBlockID/fop.py > FOP_AdBlockID/_diff/fop.patch
git diff --no-index --histogram -- VICHS/VICHS.sh VICHS_AdBlockID/VICHS.sh > VICHS_AdBlockID/_diff/VICHS.patch
git diff --no-index --histogram -- VICHS/readme.md VICHS_AdBlockID/readme.md > VICHS_AdBlockID/_diff/readme.md.patch
