# Deliverybot GitOps example

This example sets up a GitHub repository as a source of truth for [Flux][flux]
to read and to apply manifests into your Kubernetes cluster. It also has a
corresponding GitHub action which can push manifests to this repository to
deploy your code.

This brings the benefits of GitOps together with the ease of managing deployment
automation with Deliverybot. Click a button and watch manifests be updated and
deployed to your Kubernetes cluster!

![Flux diagram](https://deliverybot.dev/assets/images/integrations/flux.svg)

**This is currently in beta and the API around this may change.**

## Getting started

Requires `cfssl` to be installed along with `helm` and `kubectl`.

1. Copy this repository to your organization.

2. Run the [`./install.sh`](install.sh) script to setup FluxCD or follow this
   guide [here][flux-guide].

```bash
GIT_REPO=git@github.com:myrepo/example-gitops.git GIT_PATH=deploy NAMESPACE=kube-system ./install.sh
```

3. Create a new repository to emulate an application that you want to deploy to
   Kubernetes and install the GitOps action https://github.com/deliverybot/gitops

4. [Install the repository][deliverybot] on Deliverybot.

4. Trigger a deployment and watch the action push a change to your flux repo!

[flux]: https://fluxcd.io
[flux-guide]: https://docs.fluxcd.io/projects/helm-operator/en/latest/tutorials/get-started.html
[deliverybot]: https://github.com/apps/deliverybot/installations/new
