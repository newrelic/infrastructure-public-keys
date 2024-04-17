[![Community Project header](https://github.com/newrelic/opensource-website/raw/master/src/images/categories/Community_Project.png)](https://opensource.newrelic.com/oss-category/#community-project)

# New Relic Infrastructure Public Keys

This project consists on building a debian package, `newrelic-infra-public-keys`, which contains the public key for both the
key that is currently being used for signing (“current key”), and the key that will be used after the rotation takes place
(“future key”). The future key is generated in advance, but not used to sign packages until a reasonable time
(“update window”) passes.

`newrelic-infra-public-keys` would be a dependency of all New Relic core packages. As users upgrade packages, they will get the
latest version of newrelic-infra-public-keys, which adds to their system’s truststore the future key. After the update window
passes, New Relic will start to sign packages and repository metadata with the future key, effectively making it the
current key. The previous current key ("old key") is removed from the newrelic-infra-public-keys package, and a new future
key is generated and added to the package.

The following diagram illustrates the process. In State 1, 0xAAAA is the current key, and 0xBBBB the future key. All NR
packages are signed with 0xAAAA, but the newrelic-infra-public-keys package is already deploying 0xBBBB as a valid key. After
some time passes, State 2 is reached when 0xBBBB becomes the current key and packages start to get signed with it. A new
key, 0xCCCC is generated and its public counterpart deployed, and the process restarts with 0xBBBB being the current key
and 0xCCCC the future key.

![Signing Key Diagram](./doc/signing_key_diagram.png "Signing Key Diagram")

## Installation

This package will be installed within the newrelic-infra as a dependency

## Build

Current command will leave the generated deb package under `./pkg` folder
```shell
PGK_VERSION=1.2.3 make build
```

## Support

New Relic hosts and moderates an online forum where customers can interact with New Relic employees as well as other customers to get help and share best practices. Like all official New Relic open source projects, there's a related Community topic in the New Relic Explorers Hub. You can find this project's topic/threads here:

>Add the url for the support thread here: discuss.newrelic.com

## Contribute

We encourage your contributions to improve  New Relic Infrastructure Public Keys! Keep in mind that when you submit your pull request, you'll need to sign the CLA via the click-through using CLA-Assistant. You only have to sign the CLA one time per project.

If you have any questions, or to execute our corporate CLA (which is required if your contribution is on behalf of a company), drop us an email at opensource@newrelic.com.

**A note about vulnerabilities**

As noted in our [security policy](../../security/policy), New Relic is committed to the privacy and security of our customers and their data. We believe that providing coordinated disclosure by security researchers and engaging with the security community are important means to achieve our security goals.

If you believe you have found a security vulnerability in this project or any of New Relic's products or websites, we welcome and greatly appreciate you reporting it to New Relic through [our bug bounty program](https://docs.newrelic.com/docs/security/security-privacy/information-security/report-security-vulnerabilities/).

If you would like to contribute to this project, review [these guidelines](./CONTRIBUTING.md).

## License
New Relic Infrastructure Public Keys is licensed under the [Apache 2.0](http://apache.org/licenses/LICENSE-2.0.txt) License.

