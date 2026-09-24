import json,random,time,urllib.error,urllib.request
url="http://localhost:8099/api/checkout"
for index in range(200):
 payload=json.dumps({"cartId":f"CART-{index:04d}","items":random.randint(1,8),"total":round(random.uniform(5,500),2)}).encode();target=url+("?simulateFailure=true" if random.random()<0.08 else "")
 request=urllib.request.Request(target,data=payload,headers={"content-type":"application/json"},method="POST")
 try:urllib.request.urlopen(request,timeout=3).read()
 except urllib.error.HTTPError:pass
 time.sleep(.05)
