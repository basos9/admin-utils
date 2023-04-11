
monact_testit()
{
  curl --resolve api.example.com:80:127.0.0.1 http://api.example.com/v1/alive | grep -q '"code":200}'
}
