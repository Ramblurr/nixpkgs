# Invoice Ninja {#module-services-invoiceninja}

[Invoice Ninja](https://github.com/tchapi/invoiceninja/) is an invoicing,
expenses and tasks tracking platform for small businesses.


## Basic Usage {#module-services-invoiceninja-basic-usage}

You'll need to create an secret file containing `APP_KEY` (and any other secret env vars you want to set).

You can generate the `APP_KEY` value with  `echo "base64:"$(head -c 32 /dev/urandom | base64)`

After that, `invoiceninja` can be deployed like this:
```
{
  services.nginx = {
    enable = true;
  };
  services.invoiceninja = {
    enable = true;
    domain = "invoices.example.com";
    environmentFile = "/run/secrets/invoiceninja-env";
    nginx = {
      addSSL = true;
      # other ssl
    };
  };
}
```

This deploys Invoice Ninja using a local MariaDB and Redis instance.

After deploying visit `https://invoices.example.com/` to complete the setup workflow.
