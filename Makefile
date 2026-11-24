.SUFFIXES:
SHELL=/bin/bash
MAKEFLAGS += --jobs=8

HOSTNAME_S:=$(shell hostname -s)

MASTERS=master1 master2

update: $(addprefix .reload_,$(MASTERS))

conserver-ganeti.cf: .update-conserver-ganeti.cf
	@true

.update-conserver-ganeti.cf:
	$(eval FILE=$(subst .update-,,$@))
	./generate-ganeti-consoles.sh > "$(FILE).new"
	@if test -r "$(FILE)" && cmp -s -- "$(FILE)" "$(FILE).new" ; then \
		echo "No update" ; \
		rm "$(FILE).new" ; \
	else \
		echo "updated" ; \
		mv -f "$(FILE).new" "$(FILE)" ; \
	fi

.reload_%: conserver.cf conserver-ganeti.cf Makefile generate-ganeti-consoles.sh reset-ganeti-vm.sh send-break-to-ganeti-vm.sh .ssh
	$(eval HOST:=$(subst .reload_,,$@))
	@if [ "$(HOST)" = "$(HOSTNAME_S)" ] ; then \
		echo "$(HOSTNAME_S): Not syncing config to myself" ; \
	else \
		echo "$(HOSTNAME_S): Pushing $? to $(HOST)" ; \
		rsync -a ./ "$(HOST):/etc/conserver/" ; \
	fi
	@if [[ "$?" = *.cf* ]] ; then \
		if [ "$(HOST)" = "$(HOSTNAME_S)" ] ; then \
			echo "$(HOSTNAME_S): Local reload" ; \
			/usr/sbin/conserver -S ; \
			systemctl reload conserver-server ; \
		else \
			echo "$(HOSTNAME_S): Remote reload of $(HOST)" ; \
			ssh "$(HOST)" make -C /etc/conserver/ "$@" ; \
		fi ; \
	fi
	touch "$@"

# TODO: touch all other .reload_$(HOST) files on remote machines to.
