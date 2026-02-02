export DOCKER_BUILDKIT := 0

PROJECT = proxycam
command = docker compose -p $(PROJECT) -f docker-compose.yml
ifneq (,$(wildcard .env))
  command += --env-file .env
  include .env
endif
ifneq (,$(PIES_SYSLOG_SERVER))
  command += -f syslog.yml
  ifeq (,$(SYSLOG_SOCKET))
    export SYSLOG_SOCKET = udp://$(PIES_SYSLOG_SERVER)
  endif
else
  ifneq (,$(SYSLOG_SOCKET)$(SYSLOG_FACILITY))
    command += -f syslog.yml
  endif
endif
ifneq (,$(NEWCONFIG_DIRECTORY))
  NEWCONFIG_YML=newconfig.yml
  command += -f newconfig.yml
else
  NEWCONFIG_YML=
endif
ifneq (,$(wildcard docker-compose.override.yml))
  command += -f docker-compose.override.yml
endif
ifneq ($(TERM),xterm)
  command += --ansi=never --progress=plain
endif

F=
up_FLAGS = -d

define goal =
$(1): $(NEWCONFIG_YML)
	$$(command) $(1) $$($(strip $(1))_FLAGS)$(if $(F), $(F))
endef

all: build

ifneq (,$(NEWCONFIG_DIRECTORY))
newconfig.yml: .env
	@mkdir -p $(NEWCONFIG_DIRECTORY)
	@echo "volumes:;  newconfig:;    driver: local;    driver_opts:;      type: none;      o: bind;      device: \"$(NEWCONFIG_DIRECTORY)\";" | tr ';' '\n' > newconfig.yml
endif

proxylog:
	$(command) logs proxycam $(if $(F), $(F)) 

$(foreach verb, build config up down restart ps logs, $(eval $(call goal, $(verb))))

