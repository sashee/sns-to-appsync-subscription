import { SignatureV4 } from "@aws-sdk/signature-v4";
import { HttpRequest } from "@aws-sdk/protocol-http";
import { defaultProvider } from "@aws-sdk/credential-provider-node";
import {URL} from "url";
import {Hash} from "@aws-sdk/hash-node";

export const handler = async (event) => {
	const {APIURL, apiRegion} = process.env;
	return Promise.all(event.Records.map(async (record) => {
		const message = record.Sns.Message;
		const body = {
			query: `mutation trigger($message: String!) {
	receivedNotification(message: $message)
}`,
			operationName: "trigger",
			variables: {message},
			authMode: "AWS_IAM",
		};
		const url = new URL(APIURL);
		const httpRequest = new HttpRequest({
			body: JSON.stringify(body),
			headers: {
				"Content-Type": "application/graphql",
				host: url.hostname,
			},
			hostname: url.hostname,
			method: "POST",
			path: url.pathname,
			protocol: url.protocol,
			query: {},
		});

		const signer = new SignatureV4({
			credentials: defaultProvider(),
			service: "appsync",
			region: apiRegion,
			sha256: Hash.bind(null, "sha256"),
		});
		const req = await signer.sign(httpRequest);

		const res = await fetch(`${req.protocol}//${req.hostname}${req.path}`, {
			method: req.method,
			body: req.body,
			headers: req.headers,
		});

		if (!res.ok) {
			throw new Error("Failed");
		}
		return res.json();
	}));
};

