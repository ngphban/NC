import cloudfront = require("@aws-cdk/aws-cloudfront");
import route53 = require("@aws-cdk/aws-route53");
import s3 = require("@aws-cdk/aws-s3");
import s3deploy = require("@aws-cdk/aws-s3-deployment");
import acm = require("@aws-cdk/aws-certificatemanager");
import cdk = require("@aws-cdk/core");
import targets = require("@aws-cdk/aws-route53-targets/lib");
import { Stack, App, StackProps } from "@aws-cdk/core";
//import { RemovalPolicy } from '@aws-cdk/core';
import { Function, FunctionCode, FunctionEventType } from '@aws-cdk/aws-cloudfront';
import path = require("path");
// import { env } from "process";

export interface StaticSiteProps extends StackProps {
  domainName: string;
  siteSubDomain: string;
}

/**
 * Static site infrastructure, which deploys site content to an S3 bucket.
 *
 * The site redirects from HTTP to HTTPS, using a CloudFront distribution,
 * Route53 alias record, and ACM certificate.
 */
export class StaticSiteStack extends Stack {
  constructor(parent: App, name: string, props: StaticSiteProps) {
    super(parent, name, props);

    // console.log('User: ', process.env.USER);
    // console.log('Pass: ', process.env.PASS);

    // env: {
    //   username: process.env.USER;
    //   password: process.env.PASS;
    // }

    // const username = process.env.USER;
    // const password = process.env.PASS;
    // new cdk.CfnOutput(this, "Username", { value: username });
    // new cdk.CfnOutput(this, "Password", { value: password });

    const zone = route53.HostedZone.fromLookup(this, "Zone", {
      domainName: props.domainName,
    });
    const siteDomain = props.siteSubDomain + "." + props.domainName;
    new cdk.CfnOutput(this, "Site", { value: "https://" + siteDomain });

    // Content bucket
    const siteBucket = new s3.Bucket(this, "SiteBucket", {
      bucketName: siteDomain,
      websiteIndexDocument: "index.html",
      websiteErrorDocument: "error.html",
      publicReadAccess: true,

      // The default removal policy is RETAIN, which means that cdk destroy will not attempt to delete
      // the new bucket, and it will remain in your account until manually deleted. By setting the policy to
      // DESTROY, cdk destroy will attempt to delete the bucket, but will error if the bucket is not empty.
      removalPolicy: cdk.RemovalPolicy.DESTROY, // NOT recommended for production code
    });
    new cdk.CfnOutput(this, "Bucket", { value: siteBucket.bucketName });

    // TLS certificate
    const certificateArn = new acm.DnsValidatedCertificate(
      this,
      "SiteCertificate",
      {
        domainName: siteDomain,
        hostedZone: zone,
        region: "us-east-1", // Cloudfront only checks this region for certificates.
      }
    ).certificateArn;
    new cdk.CfnOutput(this, "Certificate", { value: certificateArn });

    // CloudFront function that authenticates View Request
    const viewRequestFunction = new Function(
      this,
      "ViewRequestFunction",
      {
        functionName: `view-request`,
        code: FunctionCode.fromFile({
          filePath: path.resolve(__dirname, "./functions/view-request/index.js"),
          
        }),
      }
    )    

    // const viewRequestFunction = new Function(
    //   this,
    //   "ViewRequestFunction",
    //   {
    //     functionName: `view-request`,
    //     code: FunctionCode.fromInline(`
    //     function handler(event) {
    //       var request = event.request;
    //       var headers = request.headers;
    //       var authUser = process.env.USER;
    //       var authPass = process.env.PASS;
    //       var tmp = authUser + ":" + authPass;
    //       var authString = 'Basic ' + tmp.toString('base64');
      
    //       if (
    //         typeof headers.authorization === "undefined" ||
    //         headers.authorization.value !== authString
    //       ) {
    //         return {
    //           statusCode: 401,
    //           statusDescription: "Unauthorized",
    //           headers: { "www-authenticate": { value: "Basic" } }
    //         };
    //       }
        
    //       return request;
    //     }
    //     `),
    //   }
    // ) 

    // CloudFront distribution that provides HTTPS
    const distribution = new cloudfront.CloudFrontWebDistribution(
      this,
      "SiteDistribution",
      {
        aliasConfiguration: {
          acmCertRef: certificateArn,
          names: [siteDomain],
          sslMethod: cloudfront.SSLMethod.SNI,
          securityPolicy: cloudfront.SecurityPolicyProtocol.TLS_V1_1_2016,
        },
        originConfigs: [
          {
            customOriginSource: {
              domainName: siteBucket.bucketWebsiteDomainName,
              originProtocolPolicy: cloudfront.OriginProtocolPolicy.HTTP_ONLY,
            },
            behaviors: [
              { 
                isDefaultBehavior: true,
                functionAssociations: [
                  {
                    eventType: FunctionEventType.VIEWER_REQUEST,
                    function: viewRequestFunction,
                  },
                ], 
              },
            ],
          },
        ],
      }
    );
    new cdk.CfnOutput(this, "DistributionId", {
      value: distribution.distributionId,
    });

    // Route53 alias record for the CloudFront distribution
    new route53.ARecord(this, "SiteAliasRecord", {
      recordName: siteDomain,
      target: route53.RecordTarget.fromAlias(
        new targets.CloudFrontTarget(distribution)
      ),
      zone,
    });

    // Deploy site contents to S3 bucket
    new s3deploy.BucketDeployment(this, "DeployWithInvalidation", {
      sources: [s3deploy.Source.asset(path.resolve(__dirname, "../../site-contents"))],
      destinationBucket: siteBucket,
      distribution,
      distributionPaths: ["/*"],
    });
  }
}