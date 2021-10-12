import cdk = require("@aws-cdk/core");
import { StaticSiteStack } from "./stacks/static-site";

const app = new cdk.App();
const staticSite = new StaticSiteStack(app, "StaticSite", {
  env: {
    account: app.node.tryGetContext("account"),
    region: app.node.tryGetContext("region"),
  },
  domainName: "cdk-demo.cf",
  siteSubDomain: "www",
});

// example of adding a tag - please refer to AWS best practices for ideal usage
cdk.Tags.of(staticSite).add("Project", "CDK Deployment Demo");

app.synth();