//! Configuration typée, chargée au démarrage. Défauts raisonnables surchargés
//! par variables d'environnement préfixées `APP_` (séparateur `__`).
//!
//! Exemples :
//!   APP_HTTP__PORT=9000
//!   APP_LOG__LEVEL=debug

use figment::{
    Figment,
    providers::{Env, Serialized},
};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub http: HttpConfig,
    pub log: LogConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HttpConfig {
    pub host: String,
    pub port: u16,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LogConfig {
    /// Filtre de log au format `tracing` (ex : "info", "debug,hyper=warn").
    pub level: String,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            http: HttpConfig {
                host: "0.0.0.0".to_owned(),
                port: 8080,
            },
            log: LogConfig {
                level: "info".to_owned(),
            },
        }
    }
}

impl Config {
    /// Charge la config : défauts + surcharges via l'environnement.
    ///
    /// # Errors
    /// Renvoie une erreur si une variable d'environnement a un type invalide
    /// (ex : `APP_HTTP__PORT=abc`).
    pub fn load() -> Result<Self, Box<figment::Error>> {
        Figment::from(Serialized::defaults(Config::default()))
            .merge(Env::prefixed("APP_").split("__"))
            .extract()
            .map_err(Box::new)
    }

    /// Adresse d'écoute `host:port`.
    #[must_use]
    pub fn http_addr(&self) -> String {
        format!("{}:{}", self.http.host, self.http.port)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn defaults_are_sane() {
        let cfg = Config::default();
        assert_eq!(cfg.http.port, 8080);
        assert_eq!(cfg.http_addr(), "0.0.0.0:8080");
    }
}
