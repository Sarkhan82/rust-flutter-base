//! Use cases (services applicatifs du domaine) : orchestrent les ports.

pub mod get_user;
pub mod list_users;
pub mod register_user;

pub use get_user::GetUser;
pub use list_users::ListUsers;
pub use register_user::{RegisterError, RegisterUser};
