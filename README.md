# NGINX Gateway Fabric Lab

This repository provides a full lab walkthrough for [NGINX Gateway Fabric](https://github.com/nginx/nginx-gateway-fabric) and several use cases.

## Overview

This repository provides a comprehensive walkthrough of leveraging NGINX Gateway Fabric within a Kubernetes environment.
It showcases a variety of use cases, demonstrating how to effectively implement and manage gateway services for microservices architectures.
The lab includes step-by-step instructions, configuration examples, and practical scenarios that illustrate the powerful features of NGINX Gateway Fabric, such as traffic management, security enhancements, and load balancing.

Whether you're a beginner looking to learn or an experienced developer seeking to deepen your understanding of NGINX Gateway Fabric in Kubernetes, this repository equips you with the necessary resources and insights to publish and secure efficient and scalable applications.

## Getting Started

Prerequisites to use this repository are:

* Running Kubernetes cluster
* Kubectl
* [jq](https://github.com/jqlang/jq) 
* [grpcurl](https://github.com/fullstorydev/grpcurl)
* Python 3.14 or later
* An F5 BIG-IP system (only for [Lab 13](labs/13.gatewaylink/))
* Access to [F5 AI Guardrails](https://www.f5.com/products/ai-guardrails) (only for [Lab 15](labs/15.ai-guardrails/))
* Valid NGINX Plus license. You can request a trial license [here](https://www.f5.com/trials/nginx-one)
  * Three files are needed (sample names here are from a trial license): `nginx-one-eval.crt` `nginx-one-eval.key` and `nginx-one-eval.jwt`

## Deployment

| Lab | [Deploy](/DEPLOYING.md) NGINX Gateway Fabric and F5 WAF for NGINX | [Deploy](/labs) use case directly |
| :--- | :---: | :---: |
| [Lab 1](labs/1.basic-app) - Basic URI-based routing | ✅ | ❌ |
| [Lab 2](labs/2.advanced-routing) - Advanced routing using HTTP matching conditions | ✅ | ❌ |
| [Lab 3](labs/3.http-headers) - Modify HTTP request and response headers | ✅ | ❌ |
| [Lab 4](labs/4.tls-offload) - TLS offload | ✅ | ❌ |
| [Lab 5](labs/5.traffic-splitting) - Traffic splitting | ✅ | ❌ |
| [Lab 6](labs/6.grpc) - gRPC support | ✅ | ❌ |
| [Lab 7](labs/7.fastcgi) - Publishing a FastCGI application using SnippetsFilter | ✅ | ❌ |
| [Lab 8](labs/8.auth-jwt) - JWT authentication | ✅ | ❌ |
| [Lab 9](labs/9.rate-limit) - Rate limiting | ✅ | ❌ |
| [Lab 10](labs/10.inference-extensions) - Gateway API Inference Extension | ✅ | ❌ |
| [Lab 11](labs/11.waf) - F5 WAF for NGINX using bundle source | ✅ | ❌ |
| [Lab 12](labs/12.waf-plm) - F5 WAF for NGINX using Policy Lifecycle Manager | ❌ | ✅ |
| [Lab 13](labs/13.gatewaylink) - Integration with F5 BIG-IP as an external load balancer | ❌ | ✅ |
| [Lab 14](labs/14.externaldns) - Integration with ExternalDNS | ❌ | ✅ |
| [Lab 15](labs/15.ai-guardrails) - Integration with F5 AI Guardrails to secure LLM traffic | ❌ | ✅ |

> [!NOTE]
> Labs 1–11 use the shared [DEPLOYING.md](/DEPLOYING.md) setup, whereas Labs 12 (waf-plm), 13 (gatewaylink), 14 (externaldns), and 15 (AI Guardrails) are self-contained and deploy NGINX Gateway Fabric directly within each lab.

## Removal

Follow the instructions [here](/DEPLOYING.md#uninstalling) to uninstall NGINX Gateway Fabric

## Support

For support, please open a GitHub issue.  Note, the code in this repository is community supported and is not supported by F5 Networks.  For a complete list of supported projects please reference [SUPPORT.md](SUPPORT.md).

## Community Code of Conduct

Please refer to the [F5 DevCentral Community Code of Conduct](code_of_conduct.md).

## License

[Apache License 2.0](LICENSE)

## Copyright

Copyright 2014-2026 F5, Inc.

### F5 Networks Contributor License Agreement

Before you start contributing to any project sponsored by F5, Inc. (F5) on GitHub, you will need to sign a Contributor License Agreement (CLA).

If you are signing as an individual, we recommend that you talk to your employer (if applicable) before signing the CLA since some employment agreements may have restrictions on your contributions to other projects.
Otherwise by submitting a CLA you represent that you are legally entitled to grant the licenses recited therein.

If your employer has rights to intellectual property that you create, such as your contributions, you represent that you have received permission to make contributions on behalf of that employer, that your employer has waived such rights for your contributions, or that your employer has executed a separate CLA with F5.

If you are signing on behalf of a company, you represent that you are legally entitled to grant the license recited therein.
You represent further that each employee of the entity that submits contributions is authorized to submit such contributions on behalf of the entity pursuant to the CLA.
