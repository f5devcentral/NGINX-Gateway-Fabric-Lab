# NGINX Gateway Fabric Lab

This repository provides a full lab walkthrough for [NGINX Gateway Fabric](https://github.com/nginx/nginx-gateway-fabric) and several use cases.

## Overview

This repository provides a comprehensive walkthrough of leveraging NGINX Gateway Fabric within a Kubernetes environment running on Amazon Web Services.
It showcases a variety of use cases, demonstrating how to effectively implement and manage gateway services for microservices architectures.
The lab includes step-by-step instructions, configuration examples, and practical scenarios that illustrate the powerful features of NGINX Gateway Fabric, such as traffic management, security enhancements, and load balancing.

Whether you're a beginner looking to learn or an experienced developer seeking to deepen your understanding of NGINX Gateway Fabric in Kubernetes, this repository equips you with the necessary resources and insights to publish and secure efficient and scalable applications.

## Getting Started

Prerequisites to use this repository are:

* Running Kubernetes cluster
* Kubectl
* [jq](https://github.com/jqlang/jq) 
* [grpcurl](https://github.com/fullstorydev/grpcurl)
* Valid NGINX Plus license. You can request a trial license [here](https://www.f5.com/trials/nginx-one)
  * Three files are needed (sample names here are from a trial license): `nginx-one-eval.crt` `nginx-one-eval.key` and `nginx-one-eval.jwt`

## Deployment

1. Make sure all [EKS prerequisites](/EKS.md) have been correctly set up
2. [Deploy](/DEPLOYING.md) NGINX Gateway Fabric
3. [Deploy](labs) use cases

## Removal

Follow the instructions [here](/DEPLOYING.md#uninstalling) to uninstall NGINX Gateway Fabric

## Support

For support, please open a GitHub issue.  Note, the code in this repository is community supported and is not supported by F5 Networks.  For a complete list of supported projects please reference [SUPPORT.md](SUPPORT.md).

## Community Code of Conduct

Please refer to the [F5 DevCentral Community Code of Conduct](code_of_conduct.md).

## License

[Apache License 2.0](LICENSE)

## Copyright

Copyright 2014-2025 F5, Inc.

### F5 Networks Contributor License Agreement

Before you start contributing to any project sponsored by F5, Inc. (F5) on GitHub, you will need to sign a Contributor License Agreement (CLA).

If you are signing as an individual, we recommend that you talk to your employer (if applicable) before signing the CLA since some employment agreements may have restrictions on your contributions to other projects.
Otherwise by submitting a CLA you represent that you are legally entitled to grant the licenses recited therein.

If your employer has rights to intellectual property that you create, such as your contributions, you represent that you have received permission to make contributions on behalf of that employer, that your employer has waived such rights for your contributions, or that your employer has executed a separate CLA with F5.

If you are signing on behalf of a company, you represent that you are legally entitled to grant the license recited therein.
You represent further that each employee of the entity that submits contributions is authorized to submit such contributions on behalf of the entity pursuant to the CLA.
