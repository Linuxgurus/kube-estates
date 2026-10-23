# stacks

Each directory is an independent OpenTofu **stack** with its own state (see `providers.tf`
for its backend key). They are not modules and nothing references them.

## Variables are NOT in this repo

`terraform.tfvars` is in `.gitignore`, on purpose: it carries the deployment's values, and a
repository is the wrong place for them.

**Until 2026-10-23 this repo contained `stacks/{core,mantle}/terraform.tfvars` as committed
symlinks to an absolute laptop path (`/Users/jblack/.tfenvs/k8s.tfenv`, git mode `120000`).**
That made the repo plannable on exactly one machine: any other clone — a runner, another
agent, a new laptop — resolved the link to nothing and died inside a `file()` call, before it
could show a diff. The links are untracked now; the local files are untouched.

Supply the variables one of these ways:

    # 1. a file outside the repo, passed explicitly
    tofu plan -var-file="$HOME/.tfenvs/k8s.tfenv"

    # 2. an environment variable naming it
    export TF_CLI_ARGS_plan="-var-file=$HOME/.tfenvs/k8s.tfenv"
    export TF_CLI_ARGS_apply="-var-file=$HOME/.tfenvs/k8s.tfenv"

    # 3. a local terraform.tfvars you create yourself (ignored by git)
    cp ~/.tfenvs/k8s.tfenv stacks/core/terraform.tfvars

Missing values fail with *"No value for required variable"* and the variable's name. That is the
named failure we want; a broken symlink is not.
