#! /bin/bash
## vim: noet:sw=0:sts=0:ts=4

SourcemodPackage.sourcemod::download () {
	SourcemodHelper::unpackTar \
		https://sm.alliedmods.net/smdrop/1.11/sourcemod-1.11.0-git6934-linux.tar.gz \
		5717280b78f6e99cf3008aa0c5e1e1deb3b00eea3ce3b5fa0924ed8ecab2f6f9
}
