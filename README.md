# TAK Deploy

One-line installer for TAK (Team Awareness Kit) infrastructure on AWS.
## Purpose
This repository deploys TAK.NZ environments for **development and testing**. One script deploys all TAK.NZ layers in order, using the `dev-test` environment type (reduced resiliency, lower cost) by default.
It is not how TAK.NZ production and demo environments are deployed. Those use the CI/CD pipelines of the individual layer repositories (see the [TAK.NZ architecture layers](https://github.com/TAK-NZ#architecture-layers)).

## Quick Install

```bash
curl -fsSL https://tak-nz.github.io/tak-deploy/install | bash
```

## Manual Download

```bash
curl -O https://raw.githubusercontent.com/TAK-NZ/tak-deploy/main/deployAllLayers
chmod +x deployAllLayers
./deployAllLayers --help
```

## What This Does

Downloads and runs the TAK infrastructure deployment script that:
- Deploys BaseInfra (VPC, ECS, S3, certificates)
- Deploys AuthInfra (Authentik SSO, LDAP)
- Deploys TakInfra (TAK Server)
- Optionally deploys TAK Team Manager to manage orgs, teams, users, devices and channels (when DEPLOY_TAKTEAMMANAGER=true and a `tak-team-manager-config.env` file is present)
- Optionally deploys CloudTAK and MediaInfra (when DEPLOY_CLOUDTAK=true)

Layers are deployed in this order, and destroyed in reverse: BaseInfra, AuthInfra, TakInfra, Team Manager, CloudTAK, MediaInfra.

## Prerequisites

- AWS CLI configured
- Docker installed and running
- An amd64 (x86_64) machine or VM to run the script on is recommended. The script builds the Docker images locally and the ECS tasks run on x86_64. On an arm64 machine such as Apple Silicon, the script builds for `linux/amd64` instead (`DOCKER_DEFAULT_PLATFORM`), which needs amd64 emulation in Docker and makes builds slower
- Node.js and npm
- An AWS account with the Asia Pacific (New Zealand) `ap-southeast-6` region enabled (it is an opt-in region) and CDK bootstrapped there
- If you deploy CloudTAK (`DEPLOY_CLOUDTAK=true`) into a new AWS account or a newly enabled region, check your Lambda concurrent executions quota first. New accounts and regions can start at the default of 10, and Lambda keeps 10 of that for functions without reserved concurrency. The CloudTAK `pmtiles` Lambda uses provisioned concurrency (2 for `dev-test`, 10 for `prod`), so the CloudTAK stack fails to create when the quota is that low. Either [request an increase](https://console.aws.amazon.com/servicequotas/home/services/lambda/quotas) of **Concurrent executions** in the target region before deploying, or set `pmtilesProvisionedConcurrency` to `0` in `CloudTAK/cdk/cdk.json`. Setting it to `0` adds cold starts when the map first loads. ETL layers share the same concurrency pool, so a quota of 10 can also throttle them at runtime
- [Route53 hosted zone](https://github.com/TAK-NZ/base-infra/blob/main/docs/AWS_GITHUB_SETUP.md#1-route-53-dns-setup)
- TAK server zip file (takserver-docker-\<version\>.zip) from [tak.gov](https://tak.gov/products/tak-server) in current directory

## Usage

```bash
./deployAllLayers --r53ZoneName tak.your-domain.com
./deployAllLayers --destroy  # Remove all infrastructure
```

TAK Team Manager and CloudTAK are optional. To enable TAK Team Manager, edit the script and set `DEPLOY_TAKTEAMMANAGER=true` at the top of the file, and put a `tak-team-manager-config.env` file with your SMTP settings (at least `EMAIL_PASSWORD`) in the directory you run the script from. TAK Team Manager does not start without `EMAIL_PASSWORD`, so the script skips it, with a warning, when the file is missing. To enable CloudTAK deployment, set `DEPLOY_CLOUDTAK=true` in the same place.

The default region is `ap-southeast-6` (Auckland). Change `REGION` at the top of the script to deploy elsewhere.

Optional `authentik-config.env`, `takserver-config.env`, `tak-team-manager-config.env` and `cloudtak-config.env` files in the current directory are uploaded to the BaseInfra config bucket. An empty file is created for any that are missing, except `tak-team-manager-config.env`, which is only uploaded when TAK Team Manager is deployed.

See `./deployAllLayers --help` for full options.

## License

TAK.NZ is distributed under [AGPL-3.0-only](LICENSE)\
Copyright (C) 2025-2026 - Christian Elsen, Team Awareness Kit New Zealand (TAK.NZ)