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

        Build.io is a Heroku-compatible PaaS following 12-Factor App principles.
        Apps are configured entirely through environment variables (config vars),
        declare process types in a Procfile, and use buildpacks to compile code.

        Key concepts:
        - Config: all settings via ENV vars (DATABASE_URL, SECRET_KEY_BASE, etc.)
        - Procfile: declares process types (web, worker, etc.) and their commands
        - Buildpacks: auto-detected for common languages (Ruby, Node, Python, Go,
          Java, etc.) or set explicitly for custom stacks
        - Domains: each app gets a default URL; add custom domains with TLS
        - Apps: start here for quick deployment of a single service
        - Pipelines: graduate to pipelines (staging → production) for mature apps
          with review apps, promotion, and diff support

        All examples use -j (JSON output) with jq for reliable, parseable results.
        This is the recommended approach for scripting and AI agents.

        ============================================================
        COLD START: From Nothing to a Running App
        ============================================================

        Your repo needs at minimum:
        - A Procfile (e.g. `web: bundle exec puma -C config/puma.rb`)
          or a language-standard entrypoint the buildpack can detect
        - Buildpacks are auto-detected for most languages. Set them
          explicitly only if auto-detection fails or you need multiple.

        # 1. Login (one-time — saves credentials to ~/.netrc for API and git)
        bld login

        # 2. Create the app
        bld apps:create my-app -t my-team -j | jq -r '.name'

        # 3. Set buildpacks (if needed)
        bld buildpacks:add heroku/nodejs -a my-app
        bld buildpacks:add heroku/ruby -a my-app

        # 4. Set config vars
        bld config:set RAILS_ENV=production SECRET_KEY_BASE=abc123 -a my-app

        # 5. Get the git URL and add it as a remote
        GIT_URL=$(bld apps:info -a my-app -j | jq -r '.git_url')
        git remote add bld "$GIT_URL"

        # 6. Deploy via git push
        git push bld main

        # 7. Scale processes
        bld ps:scale web=2:Standard-1X worker=1 -a my-app

        # 8. Verify it's running
        bld ps -a my-app -j | jq '.[] | {type, state, command}'
        WEB_URL=$(bld apps:info -a my-app -j | jq -r '.web_url')
        curl -s "$WEB_URL" | head -20

        ============================================================
        COMMAND REFERENCE (all with jq examples)
        ============================================================

        --- Authentication ---

        bld login                              # Browser-based OAuth login
        bld whoami                             # Show current user

        --- Apps ---

        # List personal apps (names only)
        bld apps -j | jq -r '.[].name'

        # List apps for a team
        bld apps -t my-team -j | jq -r '.[].name'

        # Discover all apps: list teams first, then apps per team
        bld teams -j | jq -r '.[].name'
        bld apps -t TEAM -j | jq -r '.[].name'

        # App details — extract specific fields
        bld apps:info -a APP -j | jq '{name, git_url, web_url, region, stack}'

        # Get the git push URL
        bld apps:info -a APP -j | jq -r '.git_url'

        # Get the web URL
        bld apps:info -a APP -j | jq -r '.web_url'

        # Create an app and capture its name
        bld apps:create my-app -j | jq -r '.name'

        # Create in a team
        bld apps:create my-app -t my-team -j | jq -r '.name'

        # Show/set stack
        bld apps:stacks -a APP
        bld apps:stacks:set heroku-24 -a APP

        --- Config Vars ---

        # List all config vars as key=value
        bld config -a APP -j | jq -r 'to_entries[] | "\(.key)=\(.value)"'

        # Get a single var
        bld config:get DATABASE_URL -a APP -j | jq -r '.DATABASE_URL'

        # Set vars (multiple at once)
        bld config:set KEY1=val1 KEY2=val2 -a APP

        # Copy all vars from one app to another (via STDIN, shell format)
        bld config -a SRC_APP -s | bld config:set -a DST_APP

        # Save to a file, then restore from it
        bld config -a SRC_APP -s > env.out
        bld config:set -a DST_APP < env.out

        # Unset a var
        bld config:unset KEY -a APP

        --- Git Push Deployment ---

        # Full workflow to deploy an existing repo to an existing app:
        GIT_URL=$(bld apps:info -a APP -j | jq -r '.git_url')
        git remote add bld "$GIT_URL"    # one-time setup
        git push bld main                # deploy

        # Credentials are stored in ~/.netrc by `bld login` for both
        # the API host and the git host, so git push works immediately.

        --- Processes (Dynos) ---

        # List processes with state
        bld ps -a APP -j | jq '.[] | {type, state, size, command}'

        # Scale
        bld ps:scale web=2 -a APP
        bld ps:scale web=1:Standard-2X worker=3:Standard-1X -a APP

        # Restart all
        bld ps:restart -a APP

        # Run a one-off command (args passed literally — no shell re-parsing)
        bld run bash -a APP
        bld run rails console -a APP

        # Use -c when you want the remote shell to interpret metacharacters
        bld run -c 'echo $RAILS_ENV | tee /tmp/env' -a APP

        # Pipe a local file as stdin to avoid quoting entirely
        bld run rails runner -a APP --file script.rb
        bld run rails runner -a APP < script.rb

        # Exec into a running dyno
        bld ps:exec 'ls -la /app' -a APP

        --- Buildpacks ---

        # List buildpack URLs
        bld buildpacks -a APP -j | jq -r '.[].buildpack.url'

        # Add (append)
        bld buildpacks:add heroku/nodejs -a APP

        # Insert at position 1
        bld buildpacks:add heroku/ruby -a APP -i 1

        # Replace first buildpack
        bld buildpacks:set heroku/python -a APP

        # Remove by name
        bld buildpacks:remove heroku/nodejs -a APP

        # Remove by index
        bld buildpacks:remove -i 2 -a APP

        # Clear all
        bld buildpacks:clear -a APP

        --- Addons ---

        # List addons for an app
        bld addons -a APP -j | jq '.[] | {name, plan: .plan.name, state}'

        # Browse available services — IMPORTANT: use -j to see the summary
        # field, which describes what the service actually is (e.g. "PostgreSQL
        # as a Service"). The slug name alone is often not descriptive enough.
        bld addons:services -j | jq '.[] | {name, summary, state}'

        # Find a specific type of service (e.g. postgres)
        bld addons:services -j | jq '.[] | select(.summary | test("postgres"; "i")) | {name, summary}'

        # List plans and pricing for a service
        bld addons:plans SERVICE -j | jq '.[] | {name, price}'

        # Provision an addon
        bld addons:create SERVICE:PLAN -a APP

        # Example: provision a PostgreSQL database
        # 1. Find the postgres service:
        #    bld addons:services -j | jq '.[] | select(.summary | test("postgres"; "i")) | .name'
        #    => "schema-to-go"
        # 2. List plans:
        #    bld addons:plans schema-to-go -j | jq '.[] | {name, price}'
        # 3. Provision:
        #    bld addons:create schema-to-go:mini -a APP

        # Destroy
        bld addons:destroy ADDON_NAME

        # Attach/detach across apps
        bld addons:attach ADDON_NAME -a OTHER_APP
        bld addons:detach ADDON_NAME -a OTHER_APP

        --- Domains ---

        Every app gets a default *.onbld.com URL. Add custom domains for production:

        # List domains
        bld domains -a APP -j | jq -r '.[].hostname'

        # Add a custom domain
        bld domains:add www.example.com -a APP

        # Point your DNS CNAME to the target shown by:
        bld domains:info www.example.com -a APP -j | jq -r '.cname'

        # TLS is provisioned automatically. Wait for it:
        bld domains:wait www.example.com -a APP

        --- Pipelines (for mature apps) ---

        Start with a single app for quick iteration. When ready for a
        staging → production workflow, create a pipeline:

        # List pipelines
        bld pipelines -j | jq -r '.[].name'

        # Pipeline details (shows apps per stage)
        bld pipelines:info PIPELINE -j | jq '.'

        # Compare staging to production (shows commit diff)
        bld pipelines:diff -a my-app-staging

        # Promote staging to production (zero-downtime)
        bld pipelines:promote -a my-app-staging

        --- Logs ---

        bld logs -a APP                        # Stream logs (follow)
        bld logs -a APP -n 200                 # Last 200 lines

        --- Teams ---

        # List your teams
        bld teams -j | jq -r '.[].name'

        # Team details
        bld teams:info TEAM -j | jq '.'

        ============================================================
        TIPS FOR AI AGENTS
        ============================================================

        1. ALWAYS use -j (JSON) and parse with jq. Never regex text output.
        2. Use -a APP on every command that targets an app.
        3. Discover apps: `bld teams -j` then `bld apps -t TEAM -j` per team.
        4. Deploy via git push — get the URL with:
             bld apps:info -a APP -j | jq -r '.git_url'
        5. Chain creation + deploy:
             NAME=$(bld apps:create foo -t team -j | jq -r '.name')
             GIT_URL=$(bld apps:info -a "$NAME" -j | jq -r '.git_url')
             git remote add bld "$GIT_URL" && git push bld main
        6. Config changes take effect on next deploy or dyno restart.
        7. Buildpack changes take effect on next deploy.
        8. Scale changes take effect immediately.
        SKILLS
        ACON::Command::Status::SUCCESS
      end
    end
  end
end
