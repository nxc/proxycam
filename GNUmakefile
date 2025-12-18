export DOCKER_BUILDKIT := 0

PROJECT = proxy
command = docker compose -p $(PROJECT) \
     -f docker-compose.yml
ifneq (,$(wildcard docker-compose.override.yml))
  command += -f docker-compose.override.yml
endif
ifneq (,$(wildcard .env))
  command += --env-file .env
endif
ifneq ($(TERM),xterm)
  command += --ansi=never
endif

F=
up_FLAGS = -d

define goal =
$(1):
	$$(command) $(1) $$($(strip $(1))_FLAGS)$(if $(F), $(F))
endef

all: build

$(foreach verb, build config up down restart ps logs, $(eval $(call goal, $(verb))))

