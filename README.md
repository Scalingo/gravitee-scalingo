# Gravitee.io

Scaffold of project to deploy Gravitee alongside the buildpack https://github.com/Scalingo/gravitee-buildpack

## One script deploy

```sh
./tools/deploy.sh acme
```

This will deploy and configure the following scalingo apps:

* `acme-gr-api` → REST API
* `acme-gr-gateway` → Gateway
* `acme-gr-mgmt` → Management Front-End
* `acme-gr-portal` → Developer Portal Front-End
