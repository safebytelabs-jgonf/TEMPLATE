################################################################################
###
###  Makefile for managing database migrations using Sqitch
###  v.1.0.0
###  Author: Jonathan Gonzalez <jgonf@safebytelabs.com>
###  Creation date: 2024-04-01
###  Last update: 2024-04-24
###  License: MPL-2.0
###
################################################################################
#
# How this Makefile works:
#
# 	 1. Run
#			'make gen-from-env' to generate Makefile.env from .env file
#		  or
#			'make gen-from-unix' to generate Makefile.env from UNIX environment variables
#
# 	 2. Run 'set -a; source Makefile.env' to export the environment variables
#
# 	 3. Run 'make create-db' to create the database using 'create_database.sql' script
#
# 	 4. Run 'make init' to initialize a new Sqitch project in its project folder
#
# 	 5. Run 'make add' to add a new change to the project using a wizzard
#
# 	 6. Run 
#			'make deploy' to deploy changes to the database
# 		  or
#			'make deploy-change' to deploy a specific change to the database
#
# 	 7. Run 
#			'make revert' to revert the last deployed change
# 		  or
#			'make revert-one' to revert one change back in deploy history
# 		  or
#			'make revert-to-root' to revert all changes to the initial state
#
# 	 8. Run 'make verify' to verify current deployment
#
# 	 9. Run 'make status' to show status of deployed changes
#
# 	10. Run 'make log' to show log of deployed changes
#
# 	11. Run 'make clean-sqitch' to clean Sqitch project
#
# 	12. Run 'make help' to show this help message
#
# ##############################################################################
#
# Note:
# This line is defining a set of phony targets. In a Makefile, a target is
# usually the name of a file that is generated by a program or a command.
# Dependencies are files that are used as input to create the target. A target
# can also be the name of an action to carry out, such as 'clean' (delete all
# temporary files).
#
# A phony target is one that is not really the name of a file. It is just a name
# for a recipe to be executed while making an explicit request. There are two
# reasons to use a phony target, to avoid a conflict with a file of the same
# name, and to improve performance.
#
.PHONY: gen-from-env \
        gen-from-unix \
        create-db \
        init \
        add \
        deploy \
        deploy-change \
        revert \
        revert-one \
        verify \
        status \
        log \
        clean-sqitch \
        help

# ##############################################################################
#
# Default target
#
# ##############################################################################

# Default action is to show help
default: help

# ##############################################################################
#
# Configure the database connection
#
# ##############################################################################

gen-from-env:
	@cat .env | grep -v '^#' | while IFS= read -r line; do \
		if [ -n "$$line" ]; then \
			key=$$(echo $$line | cut -d '=' -f 1); \
			value=$$(echo $$line | cut -d '=' -f 2-); \
			if [ -n "$$key" ]; then \
				echo "$$key=$$value" >> Makefile.env; \
			fi; \
		fi; \
	done
	@echo "Makefile.env generated"
	@echo "Please review the generated Makefile.env file before running any commands"
	@echo "If you need to change any values, update the .env file and run 'make generate-env' again"
	@echo "If you're ready to proceed, run 'set -a; source Makefile.env' to export the environment variables"

gen-from-unix:
	@echo "Generating Makefile.env from UNIX environment variables..."
	@if [ -z "$(PROJECT_NAME)" ]; then \
		echo "ERROR: PROJECT_NAME environment variable is not defined"; \
		exit 1; \
	fi
	@if [ -z "$(SQITCH_DIR)" ]; then \
		echo "ERROR: SQITCH_DIR environment variable is not defined"; \
		exit 1; \
	fi
	@if [ -z "$(DB_ENGINE)" ]; then \
		echo "ERROR: DB_ENGINE environment variable is not defined"; \
		exit 1; \
	fi
	@if [ -z "$(DB_USER)" ]; then \
		echo "ERROR: DB_USER environment variable is not defined"; \
		exit 1; \
	fi
	@if [ -z "$(DB_PASS)" ]; then \
		echo "ERROR: DB_PASS environment variable is not defined"; \
		exit 1; \
	fi
	@if [ -z "$(DB_HOST)" ]; then \
		echo "ERROR: DB_HOST environment variable is not defined"; \
		exit 1; \
	fi
	@if [ -z "$(DB_PORT)" ]; then \
		echo "ERROR: DB_PORT environment variable is not defined"; \
		exit 1; \
	fi
	@if [ -z "$(DB_NAME)" ]; then \
		echo "ERROR: DB_NAME environment variable is not defined"; \
		exit 1; \
	fi
	@echo "# Makefile.env generated from UNIX environment variables" > Makefile.env
	@echo "PROJECT_NAME=$(PROJECT_NAME)" >> Makefile.env
	@echo "SQITCH_DIR=$(SQITCH_DIR)" >> Makefile.env
	@echo "DB_ENGINE=$(DB_ENGINE)" >> Makefile.env
	@echo "DB_USER=$(DB_USER)" >> Makefile.env
	@echo "DB_PASS=$(DB_PASS)" >> Makefile.env
	@echo "DB_HOST=$(DB_HOST)" >> Makefile.env
	@echo "DB_PORT=$(DB_PORT)" >> Makefile.env
	@echo "DB_NAME=$(DB_NAME)" >> Makefile.env
	@echo "Makefile.env generated"
	@echo "Please review the generated Makefile.env file before running any commands"
	@echo "If you need to change any values, update the environment variales in your shell and run 'make generate-env' again"
	@echo "If you're ready to proceed, run 'set -a; source Makefile.env' to export the environment variables"

create-db:
	@echo "Creating the database..."
	@echo "Checking if database $(DB_NAME) exists..."
	@if ! PGPASSWORD=$(DB_PASS) psql -h $(DB_HOST) -U $(DB_USER) -lqt | cut -d \| -f 1 | grep -qw $(DB_NAME); then \
		echo "Database $(DB_NAME) does not exist"; \
		PGPASSWORD=$(DB_PASS) psql -h $(DB_HOST) -p $(DB_PORT) -c "CREATE DATABASE $(DB_NAME)" -d postgres -U $(DB_USER); \
		echo "Database $(DB_NAME) created"; \
	else \
		echo "Database $(DB_NAME) already exists"; \
	fi
	@ echo "Now you can execute 'make init' to initialize a new Sqitch project in its project folder $(SQITCH_DIR)"

# ##############################################################################
#
# Work with Sqitch
#
# ##############################################################################

init:
	@sqitch init $(PROJECT_NAME) --cd $(SQITCH_DIR) --engine $(ENGINE)
	@envsubst < $(SQITCH_DIR)/sqitch.conf.template > $(SQITCH_DIR)/sqitch.conf
	@echo "Sqitch project initialized in $(SQITCH_DIR)"
	@echo "Now you can execute 'make add' to add a new change to the project"

add:
	@echo "Enter the name of the change:"
	@read change_name; \
	sqitch add --cd $(SQITCH_DIR) $$change_name
	@echo "Change $$change_name added to the project"
	@echo "Now you must edit the change script in $(SQITCH_DIR)/deploy directory"
	@echo "Remember to also add, at least, a revert script in $(SQITCH_DIR)/revert directory"
	@echo "When you're ready, run 'make deploy' to deploy the changes to the database"
	@echo "If you added more than one change, you can run 'make deploy-change' to deploy up to a specific change"

deploy:
	@echo "Deploying changes to $(DB_NAME)"
	@sqitch deploy --cd $(SQITCH_DIR) db:$(DB_ENGINE)://$(DB_USER):$(DB_PASS)@$(DB_HOST):$(DB_PORT)/$(DB_NAME)
	@echo "Changes deployed"
	@echo "If you added a verify script, you can run 'make verify' to verify the deployment"
	@echo "If you need to revert the last change, you can run 'make revert' to perform the action"

deploy-change:
	@echo "Enter the name of the change to deploy:"
	@read change_name; \
	sqitch deploy --cd $(SQITCH_DIR) db:$(DB_ENGINE)://$(DB_USER):$(DB_PASS)@$(DB_HOST):$(DB_PORT)/$(DB_NAME) $$change_name; \
	echo "Change $$change_name deployed";

revert:
	@echo "Reverting last complete change"
	@sqitch revert --cd $(SQITCH_DIR) db:$(DB_ENGINE)://$(DB_USER):$(DB_PASS)@$(DB_HOST):$(DB_PORT)/$(DB_NAME)
	@echo "Last change has been reverted successfully"

revert-one:
	@echo "Reverting one change back in deploy history"
	@sqitch revert --cd $(SQITCH_DIR) db:$(DB_ENGINE)://$(DB_USER):$(DB_PASS)@$(DB_HOST):$(DB_PORT)/$(DB_NAME) --to @HEAD^ || (echo "Revert failed"; exit 1)
	@echo "Last change has been reverted successfully"

verify:
	@echo "Verifying current deployment"
	@sqitch verify --cd $(SQITCH_DIR) db:$(DB_ENGINE)://$(DB_USER):$(DB_PASS)@$(DB_HOST):$(DB_PORT)/$(DB_NAME)
	@echo "Verification completed"

status:
	@sqitch status --cd $(SQITCH_DIR) db:$(DB_ENGINE)://$(DB_USER):$(DB_PASS)@$(DB_HOST):$(DB_PORT)/$(DB_NAME)

log:
	@echo "Log of deployed changes"
	@sqitch log --cd $(SQITCH_DIR) db:$(DB_ENGINE)://$(DB_USER):$(DB_PASS)@$(DB_HOST):$(DB_PORT)/$(DB_NAME)

clean-sqitch:
	@echo "Cleaning Sqitch project"
	@rm -rf $(SQITCH_DIR)/deploy
	@rm -rf $(SQITCH_DIR)/revert
	@rm -rf $(SQITCH_DIR)/verify
	@rm -f $(SQITCH_DIR)/sqitch.conf
	@rm -f $(SQITCH_DIR)/sqitch.plan
	@rm -f ../Makefile.env
	@echo "Dropping database $(DB_NAME)"
	PGPASSWORD=$(DB_PASS) psql -h $(DB_HOST) -p $(DB_PORT) -c "DROP SCHEMA IF EXISTS sqitch CASCADE" -d $(DB_NAME) -U $(DB_USER);
	@echo "Database $(DB_NAME) dropped"
	@echo "Sqitch project cleaned"

# ##############################################################################
#
# Help
#
# ##############################################################################

help:
	@echo "Usage: make [command]"
	@echo "Commands:"
	@echo "  gen-from-env  Generate Makefile.env from .env file"
	@echo "  gen-from-unix Generate Makefile.env from UNIX environment variables"
	@echo "  create-db     Create the database <$(DB_NAME)>"
	@echo "  init          Initialize a new Sqitch project in its project folder $(SQITCH_DIR)"
	@echo "  add           Add a new change to the project using a wizzard"
	@echo "  deploy        Deploy changes to the database"
	@echo "  deploy-change Deploy a specific change to the database"
	@echo "  revert        Revert the last deployed change"
	@echo "  revert-one    Revert one change back in deploy history"
	@echo "  verify        Verify current deployment"
	@echo "  status        Show status of deployed changes"
	@echo "  log           Show log of deployed changes"
	@echo "  clean-sqitch  Clean Sqitch project"
	@echo "  help          Show this help message"
