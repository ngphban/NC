function handler(event) {
    var request = event.request;
    var headers = request.headers;
    var authUser = 'AUTHUSER';
    var authPass = 'AUTHPASSWORD';
    var tmp = authUser + ":" + authPass;
    var authString = 'Basic ' + tmp.toString('base64');
    
    if (
      typeof headers.authorization === "undefined" ||
      headers.authorization.value !== authString
    ) {
      return {
        statusCode: 401,
        statusDescription: "Unauthorized",
        headers: { "www-authenticate": { value: "Basic" } }
      };
    }
  
  return request;
}