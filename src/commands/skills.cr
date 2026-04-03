module Build
  module Commands
    @[ACONA::AsCommand("skills")]
    class Skills < Base
      protected def configure : Nil
        self
          .name("skills")
          .description("Show how to use bld (useful for AI agents and LLMs).")
          .help("Prints a comprehensive guide to Build.io CLI commands with examples.")
      end

      protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
        output.puts <<-SKILLS
        === Build.io CLI (bld) — Skills Reference

        Build.io is a Heroku-compatible PaaS. The bld CLI manages apps, config,
        deployments, addons, domains, buildpacks, pipelines, and more.

        --- Authentication ---

        bld login                         # Browser-based OAuth login (saves to ~/.netrc)
        bld whoami                        # Show current logged-in user

        --- Git Push Deployment ---

        Deploy by pushing to an app's git URL. After `bld login`, credentials for
        the git host are stored in ~/.netrc automatically.

          1. Get the app's git URL:
               bld apps:info -a my-app
               # => Git URL: https://git.build.io/my-app.git

          2. Add as a git remote:
               git remote add bld https://git.build.io/my-app.git

          3. Push to deploy:
               git push bld main

        --- Apps ---

        bld apps                          # List personal apps
        bld apps -t TEAM                  # List apps for a team
        bld teams                         # List available teams
        bld apps:info -a APP              # Show app details (git URL, region, stack, web URL)
        bld apps:info -a APP -j           # JSON output
        bld apps:create NAME              # Create personal app
        bld apps:create NAME -t TEAM      # Create app in a team
        bld apps:stacks -a APP            # Show current stack
        bld apps:stacks:set heroku-24 -a APP  # Set stack for next build

        --- Config Vars ---

        bld config -a APP                 # List all config vars
        bld config:get KEY -a APP         # Get a specific var
        bld config:set KEY=VAL -a APP     # Set a config var
        bld config:unset KEY -a APP       # Remove a config var

        --- Processes (Dynos) ---

        bld ps -a APP                     # List running processes
        bld ps:scale web=2 -a APP         # Scale web to 2 dynos
        bld ps:scale web=1:Standard-2X -a APP  # Scale with size
        bld ps:restart -a APP             # Restart all processes
        bld ps:exec COMMAND -a APP        # Run command in a running dyno
        bld run COMMAND -a APP            # Run a one-off dyno

        --- Buildpacks ---

        bld buildpacks -a APP             # List buildpacks
        bld buildpacks:add BP -a APP      # Append a buildpack
        bld buildpacks:add BP -a APP -i 1 # Insert at position
        bld buildpacks:set BP -a APP      # Replace first buildpack
        bld buildpacks:remove BP -a APP   # Remove by name/URL
        bld buildpacks:remove -i 2 -a APP # Remove by index
        bld buildpacks:clear -a APP       # Clear all buildpacks

        --- Addons ---

        bld addons -a APP                 # List addons for an app
        bld addons:services               # List available addon services
        bld addons:plans SERVICE          # List plans for a service
        bld addons:create SERVICE:PLAN -a APP  # Provision an addon
        bld addons:info ADDON             # Show addon details
        bld addons:destroy ADDON          # Remove an addon
        bld addons:attach ADDON -a APP    # Attach addon to another app
        bld addons:detach ADDON -a APP    # Detach addon from an app

        --- Domains ---

        bld domains -a APP                # List custom domains
        bld domains:add DOMAIN -a APP     # Add a domain
        bld domains:remove DOMAIN -a APP  # Remove a domain
        bld domains:clear -a APP          # Remove all custom domains
        bld domains:info DOMAIN -a APP    # Show domain details
        bld domains:wait DOMAIN -a APP    # Wait for DNS/TLS provisioning

        --- Pipelines ---

        bld pipelines                     # List your pipelines
        bld pipelines:info PIPELINE       # Show pipeline details
        bld pipelines:diff -a APP         # Compare app to downstream
        bld pipelines:promote -a APP      # Promote to downstream

        --- Logs ---

        bld logs -a APP                   # Stream application logs
        bld logs -a APP -n 100            # Show last 100 lines

        --- JSON Output ---

        Most commands accept -j / --json for machine-readable output.

          bld apps -j                     # JSON array of apps
          bld apps:info -a APP -j         # JSON app object
          bld config -a APP -j            # JSON config vars
          bld buildpacks -a APP -j        # JSON buildpack array

        --- Tips for AI Agents ---

        - Always use -a APP to specify the target app.
        - Use -j for structured output you can parse.
        - Use `bld teams` first to discover team apps (`bld apps -t TEAM`).
        - Deploy via git push: get the URL from `bld apps:info -a APP`.
        - All mutations (config:set, buildpacks:add, etc.) take effect immediately
          or on next deploy, depending on the resource.
        SKILLS
        ACON::Command::Status::SUCCESS
      end
    end
  end
end
