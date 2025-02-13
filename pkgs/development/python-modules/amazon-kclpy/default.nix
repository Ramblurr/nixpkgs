{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  fetchpatch,
  setuptools,
  mock,
  boto3,
  pytestCheckHook,
}:

buildPythonPackage rec {
  pname = "amazon-kclpy";
  version = "3.0.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "awslabs";
    repo = "amazon-kinesis-client-python";
    tag = "v${version}";
    hash = "sha256-P/kYRFDmWcqvnAaKYx22PwtC51JlYB0qopO3+QuRHAk=";
  };

  patches = [
    (fetchpatch {
      name = "remove-deprecated-boto.patch";
      url = "https://github.com/awslabs/amazon-kinesis-client-python/commit/bd2c442cdd1b0e2c99d3471c1d3ffcc9161a7c42.patch";
      hash = "sha256-5W0qItDGjx1F6IllzLH57XCpToKrAu9mTbzv/1wMXuY=";
    })
  ];

  build-system = [ setuptools ];

  dependencies = [
    mock
    boto3
  ];

  pythonImportsCheck = [ "amazon_kclpy" ];

  nativeCheckInputs = [ pytestCheckHook ];

  meta = with lib; {
    description = "Amazon Kinesis Client Library for Python";
    homepage = "https://github.com/awslabs/amazon-kinesis-client-python";
    license = licenses.asl20;
    maintainers = with maintainers; [ psyanticy ];
    broken = true;
  };
}
