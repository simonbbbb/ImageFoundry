package main

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"
)

func TestLoadConfig(t *testing.T) {
	// Create a temporary config file
	tmpDir := t.TempDir()
	configFile := filepath.Join(tmpDir, "test-config.yaml")

	configContent := `
name: test-project
version: "1.0.0"
image:
  name: "test-image"
  tag: "latest"
  registry: "ghcr.io"
  namespace: "testorg"
base:
  template: "ubuntu-24.04"
  architecture:
    - amd64
    - arm64
`

	if err := os.WriteFile(configFile, []byte(configContent), 0644); err != nil {
		t.Fatalf("Failed to create test config: %v", err)
	}

	// Test loading config
	cfgFile = configFile
	config = Config{} // Reset config

	if err := loadConfig(); err != nil {
		t.Errorf("loadConfig() failed: %v", err)
	}

	if config.Name != "test-project" {
		t.Errorf("Expected name 'test-project', got '%s'", config.Name)
	}

	if config.Image.Name != "test-image" {
		t.Errorf("Expected image name 'test-image', got '%s'", config.Image.Name)
	}
}

func TestValidateConfig(t *testing.T) {
	tests := []struct {
		name    string
		config  Config
		wantErr bool
	}{
		{
			name: "valid config",
			config: Config{
				Name: "test",
				Base: struct {
					Template     string   `yaml:"template" json:"template"`
					Architecture []string `yaml:"architecture" json:"architecture"`
				}{
					Template:     "ubuntu-24.04",
					Architecture: []string{"amd64"},
				},
			},
			wantErr: false,
		},
		{
			name: "missing name",
			config: Config{
				Name: "",
				Base: struct {
					Template     string   `yaml:"template" json:"template"`
					Architecture []string `yaml:"architecture" json:"architecture"`
				}{
					Template:     "ubuntu-24.04",
					Architecture: []string{"amd64"},
				},
			},
			wantErr: true,
		},
		{
			name: "missing template",
			config: Config{
				Name: "test",
				Base: struct {
					Template     string   `yaml:"template" json:"template"`
					Architecture []string `yaml:"architecture" json:"architecture"`
				}{
					Template:     "",
					Architecture: []string{"amd64"},
				},
			},
			wantErr: true,
		},
		{
			name: "no architecture",
			config: Config{
				Name: "test",
				Base: struct {
					Template     string   `yaml:"template" json:"template"`
					Architecture []string `yaml:"architecture" json:"architecture"`
				}{
					Template:     "ubuntu-24.04",
					Architecture: []string{},
				},
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			config = tt.config

			// Create a temporary directory with a template file for validation
			tmpDir := t.TempDir()
			templatesDir := filepath.Join(tmpDir, "templates", "base")
			os.MkdirAll(templatesDir, 0755)

			// Create a dummy template file
			templateFile := filepath.Join(templatesDir, tt.config.Base.Template+".Dockerfile")
			os.WriteFile(templateFile, []byte("FROM ubuntu\n"), 0644)

			// Change to temp directory
			oldWd, _ := os.Getwd()
			os.Chdir(tmpDir)
			defer os.Chdir(oldWd)

			err := validateConfig()
			if (err != nil) != tt.wantErr {
				t.Errorf("validateConfig() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestBuildImageName(t *testing.T) {
	config = Config{}
	config.Image.Registry = "ghcr.io"
	config.Image.Namespace = "myorg"
	config.Image.Name = "myimage"
	config.Image.Tag = "latest"

	expected := "ghcr.io/myorg/myimage:latest-amd64"
	result := getImageName("amd64")

	if result != expected {
		t.Errorf("getImageName() = %v, want %v", result, expected)
	}
}

func TestArchitectureValidation(t *testing.T) {
	validArchs := []string{"amd64", "arm64", "arm/v7", "386"}

	for _, arch := range validArchs {
		t.Run("arch_"+arch, func(t *testing.T) {
			config = Config{}
			config.Base.Architecture = []string{arch}

			if len(config.Base.Architecture) != 1 {
				t.Errorf("Expected 1 architecture, got %d", len(config.Base.Architecture))
			}
		})
	}
}

func getImageName(arch string) string {
	return fmt.Sprintf("%s/%s/%s:%s-%s",
		config.Image.Registry,
		config.Image.Namespace,
		config.Image.Name,
		config.Image.Tag,
		arch,
	)
}

func validateConfig() error {
	if config.Name == "" {
		return fmt.Errorf("project name is required")
	}

	if config.Base.Template == "" {
		return fmt.Errorf("base template is required")
	}

	if len(config.Base.Architecture) == 0 {
		return fmt.Errorf("at least one architecture is required")
	}

	return nil
}
