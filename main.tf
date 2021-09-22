# Let's set up our cloud provider with Terraform

provider "aws" {
    region = "eu-west-1"
}

# Create a VPC

resource "aws_vpc" "sre_will_vpc_tf" {
    cidr_block = var.vpc_CIDR_block
    instance_tenancy = "default"
    enable_dns_hostnames = true

    tags = {
        Name = "sre_will_vpc_tf"
    }
}

# Create an Internet Gateway

resource "aws_internet_gateway" "sre_will_IG" {
    vpc_id = aws_vpc.sre_will_vpc_tf.id

    tags = {
        Name = "sre_will_IG_tf"
    }
}

# Create a public subnet (for app instance)

resource "aws_subnet" "sre_will_public_subnet_tf" {
    vpc_id = aws_vpc.sre_will_vpc_tf.id
    cidr_block = var.public_subnet_CIDR_block
    map_public_ip_on_launch = true

    ###
    availability_zone_id = "euw1-az1" # Needed for load-balancing task
    # Requires at least 2 subnets on different availability zones
    ###

    tags = {
        Name = "sre_will_public_subnet_tf"
    }
}

# Create security group for app instance

resource "aws_security_group" "sre_will_app_group" {
    name = "sre_will_app_sg_tf"
    description = "sre_will_app_sg_tf"
    vpc_id = aws_vpc.sre_will_vpc_tf.id

    # HTTP port, global access
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = [var.public_CIDR_block]
    }

    # SSH port, (set to 0.0.0.0/0 for global access)
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [var.private_ip]
    }

    # Port 3000 for reverse proxy
    ingress {
        from_port = 3000
        to_port = 3000
        protocol = "tcp"
        cidr_blocks = [var.public_CIDR_block]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = [var.public_CIDR_block]
    }

    tags = {
        Name = "sre_will_app_sg_tf"
    }
}

# Edit the route table (thats created with the VPC)
## Adding the route to the internet gateway

resource "aws_route" "sre_will_route_table" {
    route_table_id = aws_vpc.sre_will_vpc_tf.default_route_table_id
    destination_cidr_block = var.public_CIDR_block
    gateway_id = aws_internet_gateway.sre_will_IG.id

}

# Let's launch an EC2 instance using the app AMI
## Need to define all the information required to launch the instance

# resource "aws_instance" "app_instance" {
#     ami = var.app_ami_id
#     instance_type ="t2.micro"
#     associate_public_ip_address = true
#     vpc_security_group_ids = [
#         aws_security_group.sre_will_app_group.id
#     ]
#     subnet_id = aws_subnet.sre_will_public_subnet_tf.id

#     tags = {
#         Name = "sre_will_terraform_app"
#     }

#     key_name = var.aws_key_name

#     connection {
#         type = "ssh"
#         user = "ubuntu"
#         private_key = file(var.aws_key_path)
#         host = aws_instance.app_instance.public_ip
#     }

#     ## Old provisioner went here

# }

# Create private subnet (for db instance)

resource "aws_subnet" "sre_will_db_subnet_tf" {
    vpc_id = aws_vpc.sre_will_vpc_tf.id
    cidr_block = var.private_subnet_CIDR_block
    map_public_ip_on_launch = true

    ###
    availability_zone_id = "euw1-az2" # Needed for load-balancing task
    # Requires at least 2 subnets on different availability zones
    ###

    tags = {
        Name = "sre_will_db_subnet_tf"
    }
}

# Create security group for db instance

resource "aws_security_group" "sre_will_db_group" {
    name = "sre_will_db_sg_tf"
    description = "sre_will_db_sg_tf"
    vpc_id = aws_vpc.sre_will_vpc_tf.id

    # SSH port
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [var.private_ip]
    }

    # Port 27017 for DB
    ingress {
        from_port = 27017
        to_port = 27017
        protocol = "tcp"
        # cidr_blocks = ["${aws_instance.app_instance.public_ip}/32"]
        cidr_blocks = [var.public_CIDR_block]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = [var.public_CIDR_block]
    }

    tags = {
        Name = "sre_will_db_sg_tf"
    }
}

resource "aws_instance" "db_instance" {
    ami = var.db_ami_id
    instance_type = "t2.micro"
    associate_public_ip_address = true
    vpc_security_group_ids = [
        aws_security_group.sre_will_db_group.id
    ]
    subnet_id = aws_subnet.sre_will_db_subnet_tf.id

    tags = {
        Name = "sre_will_terraform_db"
    }

    key_name = var.aws_key_name

    connection {
        type = "ssh"
        user = "ubuntu"
        private_key = var.aws_key_path
        host = aws_instance.db_instance.public_ip
    }
}

##################################################
########//Load Balancing + Auto Scaling\\#########

######################################

resource "aws_launch_configuration" "app_launch_configuration" {
    name = "sre_will_app_launch_configuration"
    image_id = var.app_ami_id
    instance_type = "t2.micro"
    key_name = var.aws_key_name
    security_groups = [aws_security_group.sre_will_app_group.id]
}


resource "aws_autoscaling_group" "sre_will_ASG_tf" {
    name = "sre_will_ASG_tf"

    min_size = 1
    desired_capacity = 1
    max_size = 3

    vpc_zone_identifier = [
        aws_subnet.sre_will_public_subnet_tf.id,
        aws_subnet.sre_will_db_subnet_tf.id
    ]

    launch_configuration = aws_launch_configuration.app_launch_configuration.name
    
    tags = [ {
      Name = "sre_will_ASG_instance"
    } ]
}

resource "aws_lb" "sre_will_app_lb" {
    name = "sre-will-app-LB-tf"
    subnets = [
        aws_subnet.sre_will_public_subnet_tf.id,
        aws_subnet.sre_will_db_subnet_tf.id
    ]
    internal = false
    load_balancer_type = "application"
}

resource "aws_lb_target_group" "sre_will_app_TG_tf" {
    name = "sre-will-app-TG-tf"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.sre_will_vpc_tf.id
    target_type = "instance"

    tags = {
        Name = "sre_will_targetgroup_tf"
    }
}

resource "aws_lb_listener" "sre_will_lb_listener" {
    load_balancer_arn = aws_lb.sre_will_app_lb.arn
    port = 80
    protocol = "HTTP"

    default_action {
        target_group_arn = aws_lb_target_group.sre_will_app_TG_tf.arn
        type = "forward"
    }
}


resource "aws_autoscaling_attachment" "sre_will_ASG_attachment" {
    autoscaling_group_name = aws_autoscaling_group.sre_will_ASG_tf.id
    alb_target_group_arn = aws_lb_target_group.sre_will_app_TG_tf.arn
}

resource "aws_autoscaling_policy" "app_ASG_scaleup_averageCPU_policy" {
    name = "Scaleup averageCPU policy"
    policy_type = "TargetTrackingScaling"
    estimated_instance_warmup = 100
    # Use "cooldown" or "estimated_instance_warmup"
    # Error: cooldown is only used by "SimpleScaling"
    autoscaling_group_name = aws_autoscaling_group.sre_will_ASG_tf.name

    target_tracking_configuration {
        predefined_metric_specification {
            predefined_metric_type = "ASGAverageCPUUtilization"
            # Trying a different metric and CPU stays super low (cant get to 1%)
            # ASGAverageNetworkIn
        }
        target_value = 10
    }
}

####################################################################
########//Adding scale-down policy with cloudwatch metric\\#########

resource "aws_autoscaling_policy" "app_ASG_scaledown_averageCPU_policy" {
    name = "Scaledown averageCPU policy"
    scaling_adjustment = -1
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = aws_autoscaling_group.sre_will_ASG_tf.id
}

resource "aws_cloudwatch_metric_alarm" "scale_down_averageCPU_alarm_metric" {
    alarm_name = "Scaledown averageCPU alarm"
    comparison_operator = "LessThanThreshold"

    metric_name = "CPUUtilization"
    statistic = "Average"

    threshold = "50"
    period = "120"
    evaluation_periods = "2"

    namespace = "AWS/EC2"
    alarm_description = "Monitors ASG EC2 average cpu utilization (for scale down policy)"
    alarm_actions = [aws_autoscaling_policy.app_ASG_scaledown_averageCPU_policy.arn]
}

#####################################################################
########//Additional monitoring metrics + scaling policies\\#########

# NetworkIn
###########

resource "aws_autoscaling_policy" "app_ASG_scaleup_averageNetworkIn_policy" {
    name = "Scaleup averageNetworkIn policy"
    policy_type = "TargetTrackingScaling"
    estimated_instance_warmup = 100
    autoscaling_group_name = aws_autoscaling_group.sre_will_ASG_tf.name

    target_tracking_configuration {
        predefined_metric_specification {
            predefined_metric_type = "ASGAverageNetworkIn"
        }
        target_value = 1000000
    }
}

resource "aws_autoscaling_policy" "app_ASG_scaledown_averageNetworkIn_policy" {
    name = "sre_will_ASG_scale_down_averageNetworkIn_policy"
    # Scaledown averageNetworkIn policy
    scaling_adjustment = -1
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = aws_autoscaling_group.sre_will_ASG_tf.id
}

resource "aws_cloudwatch_metric_alarm" "scale_down_averageNetworkIn_alarm_metric" {
    alarm_name = "Scaledown averageNetworkIn alarm"
    comparison_operator = "LessThanThreshold"

    metric_name = "NetworkIn"
    statistic = "Average"

    threshold = "500000"
    period = "120"
    evaluation_periods = "2"

    namespace = "AWS/EC2"
    alarm_description = "Monitors ASG EC2 average network in (for scale down policy)"
    alarm_actions = [aws_autoscaling_policy.app_ASG_scaledown_averageNetworkIn_policy.arn]
}

# NetworkOut
############

# resource "aws_autoscaling_policy" "app_ASG_scaleup_averageNetworkOut_policy" {
#     name = "sre_will_app_ASG_scaleup_averageNetworkOut_policy"
#     policy_type = "TargetTrackingScaling"
#     estimated_instance_warmup = 100
#     autoscaling_group_name = aws_autoscaling_group.sre_will_ASG_tf.name

#     target_tracking_configuration {
#         predefined_metric_specification {
#             predefined_metric_type = "ASGAverageNetworkOut"
#         }
#         target_value = 1000000
#     }
# }

# resource "aws_autoscaling_policy" "app_ASG_scaledown_averageNetworkOut_policy" {
#     name = "sre_will_ASG_scale_down_averageNetworkOut_policy"
#     scaling_adjustment = -1
#     adjustment_type = "ChangeInCapacity"
#     cooldown = 300
#     autoscaling_group_name = aws_autoscaling_group.sre_will_ASG_tf.id
# }

# resource "aws_cloudwatch_metric_alarm" "scale_down_averageNetworkOut_alarm_metric" {
#     alarm_name = "sre_will_ASG_scale_down_averageNetworkOut_alarm"
#     comparison_operator = "LessThanThreshold"

#     metric_name = "NetworkIn"
#     statistic = "Average"

#     threshold = "500000"
#     evaluation_periods = "2"

#     namespace = "AWS/EC2"
#     alarm_description = "Monitors ASG EC2 average network out (for scale down policy)"
#     alarm_actions = [aws_autoscaling_policy.app_ASG_scaledown_averageNetworkIn_policy.arn]
# }