// mintjwt — build an operator/account/user chain with a chosen user expiry,
// so the server's credential-expiry path can be run without nsc.
//
// Writes, into -out: operator.jwt, SYS.jwt, APP.jwt, app-user.creds,
// sys-user.creds and server.conf (operator mode, MEMORY resolver).
package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/nats-io/jwt/v2"
	"github.com/nats-io/nkeys"
)

func must(err error) {
	if err != nil {
		panic(err)
	}
}

func main() {
	out := flag.String("out", "opmode", "output directory")
	userExp := flag.Duration("user-expires", 30*time.Second, "user JWT validity from now (0 = never)")
	accExp := flag.Duration("account-expires", 0, "APP account JWT validity from now (0 = never)")
	port := flag.Int("port", 4222, "client port")
	flag.Parse()
	must(os.MkdirAll(*out, 0o755))

	okp, err := nkeys.CreateOperator()
	must(err)
	opub, _ := okp.PublicKey()
	oc := jwt.NewOperatorClaims(opub)
	oc.Name = "CF"
	ojwt, err := oc.Encode(okp)
	must(err)

	mkAccount := func(name string, exp time.Duration) (nkeys.KeyPair, string, string) {
		akp, err := nkeys.CreateAccount()
		must(err)
		apub, _ := akp.PublicKey()
		ac := jwt.NewAccountClaims(apub)
		ac.Name = name
		if exp > 0 {
			ac.Expires = time.Now().Add(exp).Unix()
		}
		ajwt, err := ac.Encode(okp)
		must(err)
		return akp, apub, ajwt
	}
	sysKP, sysPub, sysJWT := mkAccount("SYS", 0)
	appKP, appPub, appJWT := mkAccount("APP", *accExp)

	mkUser := func(name string, akp nkeys.KeyPair, exp time.Duration) string {
		ukp, err := nkeys.CreateUser()
		must(err)
		upub, _ := ukp.PublicKey()
		uc := jwt.NewUserClaims(upub)
		uc.Name = name
		if exp > 0 {
			uc.Expires = time.Now().Add(exp).Unix()
		}
		ujwt, err := uc.Encode(akp)
		must(err)
		seed, err := ukp.Seed()
		must(err)
		creds, err := jwt.FormatUserConfig(ujwt, seed)
		must(err)
		return string(creds)
	}

	w := func(name, body string) string {
		p := filepath.Join(*out, name)
		must(os.WriteFile(p, []byte(body), 0o600))
		return p
	}
	opath := w("operator.jwt", ojwt)
	w("SYS.jwt", sysJWT)
	w("APP.jwt", appJWT)
	ucreds := w("app-user.creds", mkUser("order-svc", appKP, *userExp))
	w("sys-user.creds", mkUser("sys", sysKP, 0))
	_ = sysKP

	conf := fmt.Sprintf(`# Operator mode, minted by mintjwt at %s.
# user JWT expiry: %v   account JWT expiry: %v
port: %d
http: 8222
server_name: cfauth
operator: %q
system_account: %s
resolver: MEMORY
resolver_preload: {
  %s: %q
  %s: %q
}
`, time.Now().Format(time.RFC3339), *userExp, *accExp, *port,
		mustAbs(opath), sysPub, sysPub, sysJWT, appPub, appJWT)
	w("server.conf", conf)

	fmt.Printf("operator %s\nSYS %s\nAPP %s\nuser creds %s (expires in %v)\naccount APP expires in %v\n",
		opub, sysPub, appPub, mustAbs(ucreds), *userExp, *accExp)
}

func mustAbs(p string) string { a, err := filepath.Abs(p); must(err); return a }
