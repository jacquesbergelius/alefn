rem Builds up special testing software package

rem First part contains only Alef Null software
del f:\pub\alefnull\tests.zip
pkzip -rP f:\pub\alefnull\tests test\*.*
