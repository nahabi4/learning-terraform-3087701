module "qa" {
    source = "../modules/blog"

    environment = {
        name = "qa"
        netwrok_prefix = "10.1"
    }


}