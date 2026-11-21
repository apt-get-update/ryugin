package main

import (
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"
)

// streamProxy serves Navidrome's streams over plain http on 127.0.0.1, for Sailfish OS:
// Chum's FFmpeg has no https. QML asks for
// prefix + the escaped stream URL; Range passes through, so seeking works. Only
// Subsonic stream URLs go through. rt is the transport (nil: the default).
func streamProxy(rt http.RoundTripper) (prefix string, err error) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return "", err
	}
	target := func(r *http.Request) *url.URL {
		u, err := url.Parse(r.URL.Query().Get("u"))
		if err != nil || (u.Scheme != "https" && u.Scheme != "http") || !strings.HasSuffix(u.Path, "/rest/stream") {
			return nil
		}
		return u
	}
	proxy := &httputil.ReverseProxy{Transport: rt, Rewrite: func(r *httputil.ProxyRequest) {
		r.Out.URL = target(r.In)
		r.Out.Host = ""
	}}
	serve := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if target(r) == nil {
			http.Error(w, "not a stream", http.StatusBadRequest)
			return
		}
		proxy.ServeHTTP(w, r)
	})
	go func() { _ = http.Serve(ln, serve) }() // stops only with the program
	return "http://" + ln.Addr().String() + "/?u=", nil
}
