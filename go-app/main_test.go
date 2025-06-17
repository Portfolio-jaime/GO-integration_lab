package main

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
)

func TestHandler(t *testing.T) {
	os.Setenv("APP_NAME", "") // Limpia la variable de entorno para una prueba consistente

	req, err := http.NewRequest("GET", "/", nil)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		name := os.Getenv("APP_NAME")
		if name == "" {
			name = "Go Cloud Native App"
		}
		fmt.Fprintf(w, "Hello from %s! (version 1.0)\n", name)
	})

	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("handler returned wrong status code: got %v want %v", status, http.StatusOK)
	}

	expected := "Hello from Go Cloud Native App! (version 1.0)\n"
	if strings.TrimSpace(rr.Body.String()) != strings.TrimSpace(expected) {
		t.Errorf("handler returned unexpected body: got %v want %v", rr.Body.String(), expected)
	}
}

func TestHandlerWithAppNameEnv(t *testing.T) {
	os.Setenv("APP_NAME", "MyCustomApp") // Establece la variable de entorno

	req, err := http.NewRequest("GET", "/", nil)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		name := os.Getenv("APP_NAME")
		if name == "" {
			name = "Go Cloud Native App"
		}
		fmt.Fprintf(w, "Hello from %s! (version 1.0)\n", name)
	})

	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("handler returned wrong status code: got %v want %v", status, http.StatusOK)
	}

	expected := "Hello from MyCustomApp! (version 1.0)\n"
	if strings.TrimSpace(rr.Body.String()) != strings.TrimSpace(expected) {
		t.Errorf("handler returned unexpected body: got %v want %v", rr.Body.String(), expected)
	}

	os.Unsetenv("APP_NAME") // Limpia la variable de entorno después de la prueba
}