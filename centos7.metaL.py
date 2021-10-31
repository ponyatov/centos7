## @file
## @brief meta: custom CentOS 7 installer

from metaL import *

p = Project(
    title='''custom CentOS 7 installer''',
    about='''
* massive retail installer

* http://www.smorgasbork.com/2014/07/16/building-a-custom-centos-7-kickstart-disc-part-1/
''')

p.dev \
    // 'build-essential' \
    // 'syslinux isolinux xorriso xorriso-tcltk' \
    // 'virtualbox-6.1'

p.mk.dir // f'{"FW":<7} = $(CWD)/firmware' // f'{"GZ":<7} = $(CWD)/gz'

p.fw = Dir('firmware'); p.d // p.fw; p.fw // (giti() // '*')
p.gz = Dir('gz'); p.d // p.gz; p.gz // (giti() // '*')

p.mk.package \
    // (Sec()
        // f'{"CENTOS_BUILD":<13} = 2009'
        // f'{"CENTOS_VER":<13} = 7.9.$(CENTOS_BUILD)'
        // f'{"CENTOS_MIRROR":<13} = https://mirror.yandex.ru/centos/$(CENTOS_VER)/isos/x86_64'
        // f'{"CENTOS":<13} = CentOS-7-x86_64'
        )
p.mk.package \
    // (Sec(pfx='')
        // f'{"NETINST":<13} = $(CENTOS)-NetInstall-$(CENTOS_BUILD)'
        // f'{"NETINST_ISO":<13} = $(NETINST).iso'
        // f'{"NETINST_TORR":<13} = $(NETINST).torrent'
        // f'{"NETINST_URL":<13} = $(CENTOS_MIRROR)/$(NETINST_TORR)'
        )

p.mk.gz.value += ' $(GZ)/$(NETINST_TORR)'
p.mk.gz_ \
    // (Sec(pfx='')
        // (S('$(GZ)/$(NETINST_TORR):') // '$(CURL) $@ $(NETINST_URL)')
        )

Mod().syslinux(p)


p.sync()
