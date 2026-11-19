# TAK Deploy

One-line installer for TAK (Team Awareness Kit) infrastructure on AWS.

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
- Optionally deploys TAK Team Manager to manage orgs, teams, users, devices and channels (when DEPLOY_TAKTEAMMANAGER=true, the default)
- Optionally deploys CloudTAK and MediaInfra (when DEPLOY_CLOUDTAK=true)

Layers are deployed in this order, and destroyed in reverse: BaseInfra, AuthInfra, TakInfra, Team Manager, CloudTAK, MediaInfra.

## Prerequisites

- AWS CLI configured
- Docker installed and running
- Node.js and npm
- An AWS account with the Asia Pacific (New Zealand) `ap-southeast-6` region enabled (it is an opt-in region) and CDK bootstrapped there
- [Route53 hosted zone](https://github.com/TAK-NZ/base-infra/blob/main/docs/AWS_GITHUB_SETUP.md#1-route-53-dns-setup)
- TAK server zip file (takserver-docker-\<version\>.zip) from [tak.gov](https://tak.gov/products/tak-server) in current directory

## Usage

```bash
./deployAllLayers --r53ZoneName tak.your-domain.com
./deployAllLayers --destroy  # Remove all infrastructure
```

To skip TAK Team Manager, edit the script and set `DEPLOY_TAKTEAMMANAGER=false` at the top of the file. To enable CloudTAK deployment, set `DEPLOY_CLOUDTAK=true` in the same place.

The default region is `ap-southeast-6` (Auckland). Change `REGION` at the top of the script to deploy elsewhere.

Optional `authentik-config.env`, `takserver-config.env`, `tak-team-manager-config.env` and `cloudtak-config.env` files in the current directory are uploaded to the BaseInfra config bucket. An empty file is created for any that are missing.

See `./deployAllLayers --help` for full options.

## License

TAK.NZ is distributed under [AGPL-3.0-only](LICENSE)\
Copyright (C) 2025 - Christian Elsen, Team Awareness Kit New Zealand (TAK.NZ)