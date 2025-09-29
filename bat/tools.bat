rem Build up Alef Null software tools package
del f:\pub\alefnull\tools1.zip
pkzip -rP -x???56000.exe -xreadme.sim -xsim_read.me -xtools\include\*.asm f:\pub\alefnull\tools1 tools\*.*
