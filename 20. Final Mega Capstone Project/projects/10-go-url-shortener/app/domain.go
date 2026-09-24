package main

import("crypto/sha256";"encoding/base64";"errors";"net/url";"strings")

func normalizeURL(raw string)(string,error){value:=strings.TrimSpace(raw);if len(value)<8||len(value)>2048{return"",errors.New("INVALID_URL")};parsed,err:=url.Parse(value);if err!=nil||parsed.Host==""||(parsed.Scheme!="http"&&parsed.Scheme!="https"){return"",errors.New("INVALID_URL")};parsed.Fragment="";return parsed.String(),nil}
func codeFor(key string)string{sum:=sha256.Sum256([]byte(key));return strings.TrimRight(base64.RawURLEncoding.EncodeToString(sum[:6]),"=")}
