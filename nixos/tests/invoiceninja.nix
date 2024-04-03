import ./make-test-python.nix (
  { lib, pkgs, ... }:

  let
    testEmail = "test@test.com";
    testPassword = "test";
    mkTLSCert =
      {
        alt ? [ ],
      }:
      (pkgs.runCommand "selfSignedCert" { buildInputs = [ pkgs.openssl ]; } ''
        mkdir -p $out
        openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:secp384r1 -days 365 -nodes \
          -keyout $out/cert.key -out $out/cert.crt \
          -subj "/CN=localhost" -addext "subjectAltName=DNS:localhost,${
            builtins.concatStringsSep "," ([ "IP:127.0.0.1" ] ++ alt)
          }"
      '');
    test-cert = mkTLSCert { alt = [ ]; };
    testRunner =
      pkgs.writers.writePython3Bin "test-runner"
        {
          libraries = [ pkgs.python3Packages.selenium ];
          flakeIgnore = [ "E501" ];
        }
        ''
          from selenium.webdriver.common.by import By
          from selenium.webdriver import Firefox
          from selenium.webdriver.firefox.options import Options
          from selenium.webdriver.support.ui import WebDriverWait
          from selenium.webdriver.support import expected_conditions as EC

          options = Options()
          options.add_argument("--headless")
          options.set_capability("acceptInsecureCerts", True)
          driver = Firefox(options=options)
          driver.implicitly_wait(20)
          wait = WebDriverWait(driver, 10)


          def wait_elem(by, query):
              wait.until(EC.presence_of_element_located((by, query)))


          driver.get("https://localhost/setup")

          wait.until(EC.title_contains("Setup"))

          # remove the cookie banner that covers the buttons
          driver.execute_script(
              """
              var element = document.querySelector('.cc-banner');
              if (element) {
                  element.parentNode.removeChild(element);
              }
              """
          )

          driver.find_element(By.NAME, "url").send_keys("https://localhost")
          driver.find_element(By.CSS_SELECTOR, "button#test-pdf").click()
          wait_elem(By.CSS_SELECTOR, "button#test-db-connection")
          driver.find_element(By.CSS_SELECTOR, "button#test-db-connection").click()
          wait_elem(By.CSS_SELECTOR, "button#test-smtp-connection")
          driver.find_element(By.CSS_SELECTOR, "#test-smtp-connection").click()
          driver.find_element(By.NAME, "first_name").send_keys("Alice")
          driver.find_element(By.NAME, "last_name").send_keys("Aligator")
          driver.find_element(By.NAME, "email").send_keys("${testEmail}")
          driver.find_element(By.NAME, "password").send_keys("${testPassword}")

          checkbox = driver.find_element(By.NAME, "terms_of_service")
          if not checkbox.is_selected():
              checkbox.click()

          checkbox = driver.find_element(By.NAME, "privacy_policy")
          if not checkbox.is_selected():
              checkbox.click()
          driver.find_element(By.XPATH, '//button[@type="submit"]').click()
          wait.until(EC.title_contains("Invoice Ninja"))
        '';
  in

  {
    name = "invoiceninja";
    meta.maintainers = pkgs.invoiceninja.meta.maintainers;

    nodes.machine =
      { config, ... }:
      {
        virtualisation.memorySize = 2048;
        environment.systemPackages = [
          pkgs.firefox-unwrapped
          pkgs.geckodriver
          testRunner
        ];

        # if you do this in production, dont put secrets in this file because it will be written to the world readable nix store
        environment.etc."in/env".text = ''
          APP_KEY=base64:j6DwYpIqxk5xJVV4da9r1o5MbnIfNSQq7cFXbCSn/1k=
        '';

        services.invoiceninja = {
          enable = true;
          domain = "localhost";
          environmentFile = "/etc/in/env";
          nginx = {
            addSSL = true;
            sslCertificate = "${test-cert}/cert.crt";
            sslCertificateKey = "${test-cert}/cert.key";
          };
        };
      };

    testScript = ''
      start_all()
      machine.wait_for_unit("mysql.service")
      machine.wait_for_unit("nginx.service")
      machine.wait_for_unit("invoiceninja-data-setup.service")
      machine.wait_for_unit("phpfpm-invoiceninja.service")
      machine.sleep(5)

      with subtest("use the web interface to walk through the setup flow"):
          machine.succeed("PYTHONUNBUFFERED=1 systemd-cat -t test-runner test-runner")

      # why do we revert to curl to test the login?
      # because invoiceninja uses flutter for the frontend, which selenium cannot interact with

      def login_cmd(user, password):
          return f"""
              curl --fail --insecure -X 'POST' \
                'https://localhost/api/v1/login?include=clients%2Cinvoices&include_static=include_static%3Dtrue&clear_cache=clear_cache%3Dtrue' \
                -H 'accept: application/json' \
                -H 'X-Requested-With: XMLHttpRequest' \
                -H 'Content-Type: application/json' \
                -d '{{
                  "email": "{user}",
                  "password": "{password}"
                }}'
              """


      with subtest("use the API to login"):
          r = machine.succeed(login_cmd("${testEmail}", "${testPassword}"))
          # sanity check, bad password should fail
          r = machine.fail(login_cmd("${testEmail}", "wrong-password"))
    '';
  }
)
