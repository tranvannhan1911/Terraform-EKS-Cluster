# Terraform - EKS - Kubernetes

![Untitled](https://i.imgur.com/Q4p15Ah.png)

1. Mục tiêu
    - Sử dụng terraform để xây dựng hạ tầng như sơ đồ trên.
    - Tạo một EKS Cluster, với các node nằm trong private subnet
    - Đảm bảo high availability
    - Thực hiện deploy application lên EKS Cluster
        - Tạo ingress controller, khi người dùng request ingress controller sẽ route traffic đến service.
        - Từ service sẽ route các traffic tới các pod khả dụng.
2. Nội dung
    1. Cài đặt và cấu hình `awscli`
    2. Cài đặt `kubectl`
    3. Tạo project terraform
        - Cấu trúc file
            
            ```yaml
            |   iam.tf
            |   main.tf
            |   node_group_keypair.pub
            |   provider.tf
            |   variables.tf
            \---vpc
                |   data_source.tf
                |   igw.tf
                |   nat_gw.tf
                |   provider.tf
                |   route_table.tf
                |   subnet.tf
                |   variables.tf
                |   vpc.tf
            ```
            
        1. Tạo module VPC
            - Tóm tắt
                - `VPC` bao gồm 1 `public subnet` và 1 `private subnet` ở mỗi `AZ`
                - Với mỗi `AZ` đặt một `NAT gateway` để có thể kết nối internet, các service bên ngoài từ các instance trong `private subnet`. Mỗi `NAT gateway` sẽ được allocate với một `EIP` (Elastic IP)
                - Tạo 3 `route table` cho 3 `private subnet`, thêm rule đi từ `private subnet` ra internet thông qua `NAT gateway` của `AZ` tương ứng.
                - Tạo 1 `route table` cho 3 `public subnet`, thêm rule đi từ `public subnet` ra internet thông qua `IGW`.
                - Output `vpc`, `public subnets`, `private subnets`
            - Tạo module `vpc` (Tạo thư mục `vpc`)
            - `variables.tf`
                
                ```bash
                variable "region" {
                  default = "ap-southeast-1"
                }
                variable "cidr_block" {
                  default = "10.0.0.0/16"
                }
                variable "cidr_block_public_subnet" {
                  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
                }
                variable "cidr_block_private_subnet" {
                  default = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
                }
                ```
                
                - Chứa các biến được sử dụng trong module
                - `region`: region aws
                - `cidr_block`: cidr block được sử dụng cho VPC
                - `cidr_block_public_subnet`: cidr block được sử dụng cho public subnet, các cidr block này phải là tập con của cidr block của VPC, và không được conflict với nhau (không chồng lẫn lên nhau).
                - `cidr_block_private_subnet`: cidr block được sử dụng cho private subnet, các cidr block này phải là tập con của cidr block của VPC, và không được conflict với nhau (không chồng lẫn lên nhau).
            - Tạo `vpc` (vpc.tf)
                - [https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc)
                
                ```bash
                resource "aws_vpc" "eks_vpc" {
                  cidr_block = var.cidr_block
                
                  tags = {
                    Name = "EKS VPC"
                  }
                }
                ```
                
                - `cidr_block`: là cidr block đã được khai báo trong `variables.tf`
            - Lấy danh sách `availability zone` trong `region` (data_source.tf)
                
                ```bash
                data "aws_availability_zones" "az" {
                  state = "available"
                }
                ```
                
                - `state = "available"`: Chỉ trả về các AZ khả dụng
            - Tạo public subnet (subnet.tf)
                - [https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet)
                
                ```bash
                resource "aws_subnet" "public_subnet" {
                  count                   = length(var.cidr_block_public_subnet)
                  vpc_id                  = aws_vpc.eks_vpc.id
                  cidr_block              = var.cidr_block_public_subnet[count.index]
                  availability_zone       = data.aws_availability_zones.az.names[count.index]
                  map_public_ip_on_launch = true
                
                  tags = {
                    Name = "EKS public subnet ${count.index + 1}"
                  }
                }
                ```
                
                - `count = length(var.cidr_block_public_subnet)`: Với mỗi `AZ` tạo một `public subnet` tương ứng.
                - `vpc_id = aws_vpc.eks_vpc.id`: `VPC` đã tạo phía trên
                - `cidr_block = var.cidr_block_public_subnet[count.index]`: Lấy `cidr block` trong danh sách `cidr_block_public_subnet` ở vị trí `count.index`
                - `availability_zone = data.aws_availability_zones.az.names[count.index]`: Lấy `AZ` từ danh sách `AZ` ở vị trí `count.index`
                - `map_public_ip_on_launch = true`: Nếu các instance được tạo trong subnet này, nó sẽ được gán địa chỉ IP public.
            - Tạo private subnet (subnet.tf)
                - [https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet)
                
                ```bash
                resource "aws_subnet" "private_subnet" {
                  count             = length(var.cidr_block_private_subnet)
                  vpc_id            = aws_vpc.eks_vpc.id
                  cidr_block        = var.cidr_block_private_subnet[count.index]
                  availability_zone = data.aws_availability_zones.az.names[count.index]
                
                  tags = {
                    Name = "EKS private subnet ${count.index + 1}"
                  }
                }
                ```
                
                - Tương tự như public subnet
            - Tạo igw (igw.tf)
                - [https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway)
                
                ```bash
                resource "aws_internet_gateway" "igw" {
                  vpc_id = aws_vpc.eks_vpc.id
                
                  tags = {
                    Name = "Internet gateway"
                  }
                }
                ```
                
            - Tạo route table cho public subnet (route_table.tf)
                - [https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table)
                
                ```bash
                resource "aws_route_table" "route_table_public_subnet" {
                  vpc_id = aws_vpc.eks_vpc.id
                  tags = {
                    Name = "Route table public subnet"
                  }
                }
                ```
                
                - Tạo route table `route_table_public_subnet`
                - Tạo route đi từ public subnet ra internet thông qua `igw`
                    - [https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route)
                    
                    ```bash
                    resource "aws_route" "route_public_subnet" {
                      route_table_id         = aws_route_table.route_table_public_subnet.id
                      destination_cidr_block = "0.0.0.0/0"
                      gateway_id             = aws_internet_gateway.igw.id
                    }
                    ```
                    
                    - `destination_cidr_block = "0.0.0.0/0"`: Đích đến của route, `0.0.0.0/0` là internet.
                    - `gateway_id = aws_internet_gateway.igw.id`: đi ra internet thông qua `igw`
                - Associate các public subnet vào route table
                    - [https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association)
                    
                    ```bash
                    resource "aws_route_table_association" "route_table_public_subnet_association" {
                      count          = length(aws_subnet.public_subnet)
                      subnet_id      = aws_subnet.public_subnet[count.index].id
                      route_table_id = aws_route_table.route_table_public_subnet.id
                    }
                    ```
                    
                    - Associate tất cả public subnet vào cùng một route table
            - Tạo `NAT gateway`
                - [https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip)
                - [https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway)
                
                ```bash
                resource "aws_eip" "eip_nat_gw" {
                  count = length(var.cidr_block_private_subnet)
                }
                
                resource "aws_nat_gateway" "nat_gw" {
                  count         = length(aws_subnet.public_subnet)
                  subnet_id     = aws_subnet.public_subnet[count.index].id
                  allocation_id = aws_eip.eip_nat_gw[count.index].id
                
                  tags = {
                    Name = "NAT Gateway"
                  }
                }
                ```
                
                - Mỗi `NAT gateway` sẽ được gán một địa chỉ ip riêng (EIP)
                - `subnet_id = aws_subnet.public_subnet[count.index].id`: Vị trí mà `nat gateway` được tạo, `nat gateway` sẽ được tạo trong các public subnet, rồi từ public subnet yêu cầu đi ra internet bằng `igw`: `instance` → `nat gateway` → `igw`
            - Tạo route table cho private subnet (route_table.tf)
                
                ```bash
                resource "aws_route_table" "route_table_private_subnet" {
                  count  = length(aws_subnet.private_subnet)
                  vpc_id = aws_vpc.eks_vpc.id
                  tags = {
                    Name = "Route table private subnet"
                  }
                }
                ```
                
                - Với mỗi private subnet tạo các route table tương ứng, vì mỗi private subnet thuộc một AZ riêng có 1 NAT gateway riêng.
                - Tạo route đi ra internet cho các private subnet
                    
                    ```bash
                    resource "aws_route" "route_private_subnet" {
                      count                  = length(aws_route_table.route_table_private_subnet)
                      route_table_id         = aws_route_table.route_table_private_subnet[count.index].id
                      destination_cidr_block = "0.0.0.0/0"
                      nat_gateway_id         = aws_nat_gateway.nat_gw[count.index].id
                    }
                    ```
                    
                    - Mỗi private subnet sẽ có 1 NAT gateway riêng
                - Associate các private subnet vào route table
                    
                    ```bash
                    resource "aws_route_table_association" "route_table_private_subnet_association" {
                      count          = length(aws_route_table.route_table_private_subnet)
                      route_table_id = aws_route_table.route_table_private_subnet[count.index].id
                      subnet_id      = aws_subnet.private_subnet[count.index].id
                    }
                    ```
                    
                    - Associate subnet vào route table tương ứng.
            - Output (vpc.tf)
                
                ```bash
                output "vpc" {
                  value = aws_vpc.eks_vpc
                }
                
                output "public_subnets" {
                  value = aws_subnet.public_subnet
                }
                
                output "private_subnets" {
                  value = aws_subnet.private_subnet
                }
                ```
                
                - Trả về vpc, public subnets, private subnets.
        2. Tạo EKS cluster
            - Tạo variables (variables.tf)
                
                ```bash
                variable "region" {
                  default = "ap-southeast-1"
                }
                variable "cidr_block" {
                  default = "10.0.0.0/16"
                }
                variable "cidr_block_public_subnet" {
                  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
                }
                variable "cidr_block_private_subnet" {
                  default = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
                }
                variable "cluster_name" {
                  default = "hiitfigure"
                }
                ```
                
            - Tạo `vpc` từ module vpc (main.tf)
                
                ```bash
                module "vpc" {
                  source = "./vpc"
                
                  region                   = var.region
                  cidr_block               = var.cidr_block
                  cidr_block_public_subnet = var.cidr_block_public_subnet
                }
                ```
                
                - `source = "./vpc"`: Đường dẫn tới module
                - `region = var.region`: Truyền các biến vào module
            - Tạo `IAM role` cho `EKS Cluster` (iam.tf)
                - [https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster#example-iam-role-for-eks-cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster#example-iam-role-for-eks-cluster)
                
                ```bash
                # IAM Role for cluster
                resource "aws_iam_role" "iam_role" {
                  name = "eks-cluster-iam-role"
                
                  assume_role_policy = <<POLICY
                {
                  "Version": "2012-10-17",
                  "Statement": [
                    {
                      "Effect": "Allow",
                      "Principal": {
                        "Service": "eks.amazonaws.com"
                      },
                      "Action": "sts:AssumeRole"
                    }
                  ]
                }
                POLICY
                }
                ```
                
                - gán `policy` vào `iam role`
                    
                    ```bash
                    resource "aws_iam_role_policy_attachment" "iam-role-AmazonEKSClusterPolicy" {
                      policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
                      role       = aws_iam_role.iam_role.name
                    }
                    
                    resource "aws_iam_role_policy_attachment" "iam-role-AmazonEKSVPCResourceController" {
                      policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
                      role       = aws_iam_role.iam_role.name
                    }
                    ```
                    
                    - `AmazonEKSClusterPolicy`: Các quyền cung cấp cho k8s các quyền để nó có thể quản lý tài nguyên, như CreateTags EC2, Security Group, Elastic Network interface, load balancer, auto scaling,...
                    - `AmazonEKSVPCResourceController`: Các quyền quản lý Elastic Network Interface (ENI) và các IP cho các worker nodes.
            - Tạo `IAM role` cho `Node group` (iam.tf)
                - [https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group#example-iam-role-for-eks-node-group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group#example-iam-role-for-eks-node-group)
                - Các `IAM role` này sẽ được gán cho các `worker node` được quản lý bởi `node group`
                
                ```bash
                # IAM Role for node group
                resource "aws_iam_role" "iam_role_node_group" {
                  name = "eks-node-group"
                
                  assume_role_policy = jsonencode({
                    Statement = [{
                      Action = "sts:AssumeRole"
                      Effect = "Allow"
                      Principal = {
                        Service = "ec2.amazonaws.com"
                      }
                    }]
                    Version = "2012-10-17"
                  })
                }
                ```
                
                - Gán các `policy` vào `iam role`
                    
                    ```bash
                    resource "aws_iam_role_policy_attachment" "iam_role_node_group-AmazonEKSWorkerNodePolicy" {
                      policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
                      role       = aws_iam_role.iam_role_node_group.name
                    }
                    
                    resource "aws_iam_role_policy_attachment" "iam_role_node_group-AmazonEKS_CNI_Policy" {
                      policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
                      role       = aws_iam_role.iam_role_node_group.name
                    }
                    ```
                    
                    - `AmazonEKSWorkerNodePolicy`: Cho phép EKS worker nodes kết nối tới EKS Cluster.
                    - `AmazonEKS_CNI_Policy`: Các quyền sửa đội cấu hình địa chỉ IP trên các worker node, cho phép liệt kê, sửa đổi các network interface.
            - Tạo keypair cho các worker node
                - [https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair)
                - Tạo key pair
                    
                    ```bash
                    $ ssh-keygen
                    ```
                    
                
                ```bash
                resource "aws_key_pair" "node_group_keypair" {
                  key_name   = "node_group_keypair"
                  public_key = file("node_group_keypair.pub")
                }
                ```
                
                - `public_key = file("node_group_keypair.pub")`: Đường dẫn tới public key
            - Tạo `EKS cluster`
                - [https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster)
                
                ```bash
                resource "aws_eks_cluster" "cluster" {
                  name     = "hiitfigure"
                  role_arn = aws_iam_role.iam_role.arn
                
                  vpc_config {
                    subnet_ids = [for subnet in module.vpc.public_subnets : subnet.id]
                  }
                
                  depends_on = [
                    aws_iam_role_policy_attachment.iam-role-AmazonEKSClusterPolicy,
                    aws_iam_role_policy_attachment.iam-role-AmazonEKSVPCResourceController,
                  ]
                }
                ```
                
                - `role_arn = aws_iam_role.iam_role.arn`: `iam role` cho cluster
                - `vpc_config`: VPC được liên kết với cluster
                - `subnet_ids = [for subnet in module.vpc.public_subnets : subnet.id]`: Danh sách subnet, EKS sẽ tạo các elastic network interface ở các subnet này để cho phép giao tiếp giữa worker node và control plane.
                - `depends_on`: Đảm bảo các quyền đã được gán trước khi tạo `EKS cluster`
            - Tạo `node group`
                - [https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group)
                
                ```bash
                resource "aws_eks_node_group" "node_group" {
                  cluster_name    = aws_eks_cluster.cluster.name
                  node_group_name = "node-group"
                  node_role_arn   = aws_iam_role.iam_role_node_group.arn
                  subnet_ids      = [for subnet in module.vpc.private_subnets : subnet.id]
                
                  instance_types = ["t2.micro"]
                
                  remote_access {
                    ec2_ssh_key = aws_key_pair.node_group_keypair.key_name
                  }
                
                  scaling_config {
                    desired_size = 3
                    max_size     = 3
                    min_size     = 1
                  }
                
                  update_config {
                    max_unavailable = 2
                  }
                
                  depends_on = [
                    aws_iam_role_policy_attachment.iam_role_node_group-AmazonEKSWorkerNodePolicy,
                    aws_iam_role_policy_attachment.iam_role_node_group-AmazonEKS_CNI_Policy,
                    aws_iam_role_policy_attachment.iam_role_node_group-AmazonEC2ContainerRegistryReadOnly,
                  ]
                }
                ```
                
                - `cluster_name = aws_eks_cluster.cluster.name`: cluster đã tạo trước đó
                - `node_role_arn   = aws_iam_role.iam_role_node_group.arn`: `iam role` cho các `worker node` được tạo ra bởi `node group`
                - `subnet_ids = [for subnet in module.vpc.private_subnets : subnet.id]`: Nơi các worker node được tạo ra.
                - `ec2_ssh_key`: Trỏ tới keypair đã được tạo.
                - `scaling_config`
                    - `desired_size = 3`: số lượng worker node mong muốn
                    - `max_size = 5`: Số lượng woker node tối đa
                    - `min_size = 3`: Số lượng worker node tối thiểu
                - `max_unavailable`: Số lượng worker node không khả dụng tối đa trong quá trình cập nhật node group.
                - `depends_on`: Đảm bảo các quyền được gán trước khi tạo node group
        - Output
            
            ```bash
            output "endpoint" {
              value = aws_eks_cluster.cluster.endpoint
            }
            ```
            
            - trả về cluster endpoint
        - Apply
            
            ```yaml
            $ terraform apply --auto-approve
            ```
            
        - Kết quả
            
            ![Untitled](https://i.imgur.com/zIqVLDA.png)
            
    4. Chuẩn bị image
        - Thực hiện triển khai ứng dụng web Hiitfigure
        - Sửa lại file `application.properties`
            
            ```bash
            ...
            spring.datasource.url=jdbc:mysql://${MYSQL_DB_HOST}:${MYSQL_DB_PORT}/${MYSQL_DB_DATABASE}?autoReconnect=true&useSSL=false
            spring.datasource.username=${MYSQL_DB_USERNAME}
            spring.datasource.password=${MYSQL_DB_PASSWORD}
            ...
            cloud.aws.credentials.access-key = ${AWS_CREDENTIAL_ACCESS_KEY}
            cloud.aws.credentials.secret-key = ${AWS_CREDENTIAL_SECRET_KEY}
            ...
            spring.mail.username=${MAIL_USERNAME}
            spring.mail.password=${MAIL_PASSWORD}
            ...
            ```
            
            - Các biến này là các biến môi trường sẽ được truyền khi tạo container
        - Build artifact
            
            ```bash
            $ mvn install
            ```
            
        - Tạo file `Dockerfile`
            
            ```docker
            FROM adoptopenjdk/openjdk8:alpine
            
            WORKDIR /app
            
            COPY target/store-0.0.1-SNAPSHOT.jar .
            
            CMD ["java", "-jar", "/app/store-0.0.1-SNAPSHOT.jar"]
            ```
            
            - `FROM adoptopenjdk/openjdk8:alpine`: bản phân phối alpine linux, được cài đặt java8
            - `WORKDIR /app`: Thư mục chính
            - `COPY target/store-0.0.1-SNAPSHOT.jar .`: Sao chép artifact vào image
            - `CMD ["java", "-jar", "/app/store-0.0.1-SNAPSHOT.jar"]`: Câu lệnh khởi chạy ứng dụng trong container.
        - Tạo image
            
            ```bash
            $ docker build -t tranvannhan1911/hiitfigure .
            ```
            
        - Push image lên registry
            
            ```bash
            $ docker push tranvannhan1911/hiitfigure
            ```
            
    5. Tạo defination file cho k8s
        
        ![Untitled](https://i.imgur.com/TjseQaM.png)
        
        - Tóm tắt
            - Triển khai ứng dụng web Hiitfigure lên cluster
            - Với các biến môi trường bình thường thì sử dụng `configmap` để lưu trữ
                - MYSQL_DB_HOST
                - MYSQL_DB_PORT
                - MYSQL_DB_DATABASE
            - Với các biến môi trường về tài khoản, mật khẩu thì sử dụng secret nhằm an toàn hơn.
                - MYSQL_DB_USERNAME
                - MYSQL_DB_PASSWORD
                - AWS_CREDENTIAL_ACCESS_KEY
                - AWS_CREDENTIAL_SECRET_KEY
                - MAIL_USERNAME
                - MAIL_PASSWORD
            - Tạo deployment với template
            - Tạo service cho deployment
            - Tạo ingress trỏ vào service
        - Thêm context `EKS cluster` vào `Kubectl`
            
            ```yaml
            $ aws eks update-kubeconfig --region ap-southeast-1 --name hiitfigure
            ```
            
        - Cài đặt Ingress controller
            - [https://kubernetes.github.io/ingress-nginx/deploy/#aws](https://kubernetes.github.io/ingress-nginx/deploy/#aws)
            
            ```yaml
            $ kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.3.0/deploy/static/provider/aws/deploy.yaml
            ```
            
        - `ConfigMap`
            - [https://kubernetes.io/docs/concepts/configuration/configmap/](https://kubernetes.io/docs/concepts/configuration/configmap/)
            
            ```yaml
            apiVersion: v1
            kind: ConfigMap
            metadata:
              name: hiitfigure
              namespace: default
            data:
              MYSQL_DB_HOST: "hiitfigure.random.ap-southeast-1.rds.amazonaws.com"
              MYSQL_DB_PORT: "3306"
              MYSQL_DB_DATABASE: "figurestore"
            ```
            
            - `name: hiitfigure`: Tên configmap
            - `namespace: default`: Namespace mà configmap này được tạo
        - `Secret`
            - [https://kubernetes.io/docs/concepts/configuration/secret/](https://kubernetes.io/docs/concepts/configuration/secret/)
            
            ```yaml
            apiVersion: v1
            kind: Secret
            metadata:
              name: hiitfigure
              namespace: default
            type: Opaque
            data:
              MYSQL_DB_USERNAME: aGlpdGZRANDOM==
              MYSQL_DB_PASSWORD: aGlpdGZRANDOM==
              AWS_CREDENTIAL_ACCESS_KEY: QUtJQVNTWDdCQkxEVlRANDOM=
              AWS_CREDENTIAL_SECRET_KEY: NnRzUXIrMW9UdFBxNDBYYUMvaGVlaWI4cEkzOFozOTllSRANDOM==
              MAIL_USERNAME: aGlpdGZpZ3VyZW9mZmljaWFsQGdtYWlsRANDOM==
              MAIL_PASSWORD: ZnFkYXdidmZnZ3VRANDOM==
            ```
            
            - `name: hiitfigure`: Tên secret
            - `type: Opaque`: Loại Secret
                - `Opaque`arbitrary user-defined data
                - `kubernetes.io/service-account-token`ServiceAccount token
                - `kubernetes.io/dockercfg`serialized `~/.dockercfg` file
                - `kubernetes.io/dockerconfigjson`serialized `~/.docker/config.json` file
                - `kubernetes.io/basic-auth`credentials for basic authentication
                - `kubernetes.io/ssh-auth`credentials for SSH authentication
                - `kubernetes.io/tls`data for a TLS client or server
                - `bootstrap.kubernetes.io/token`bootstrap token data
            - Thay các giá trị bằng base64 encode
        - Tạo `deployment`
            - [https://kubernetes.io/docs/concepts/workloads/controllers/deployment/](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
            
            ```yaml
            apiVersion: apps/v1
            kind: Deployment
            metadata:
              name: hiitfigure-deployment
              labels:
                app: hiitfigure # label of deployment
            spec:
              replicas: 2
              selector:
                matchLabels:
                  app: hiitfigure  # deployment manage pods through labels of pods
              template:
                metadata:
                  labels:
                    app: hiitfigure  # label of pods
                spec:
                  containers:
                  - name: hiitfigure # name of the container
                    image: tranvannhan1911/hiitfigure # image
                    ports:
                    - containerPort: 8080 # port of the container will be exposed
                    envFrom: # environment variale
                    - configMapRef: # environment variale from configmap name hiitfigure
                        name: hiitfigure 
                    - secretRef: # environment variale from secret name hiitfigure
                        name: hiitfigure
            ```
            
        - Tạo `service`
            - [https://kubernetes.io/docs/concepts/services-networking/service/](https://kubernetes.io/docs/concepts/services-networking/service/)
            
            ```yaml
            apiVersion: v1
            kind: Service
            metadata:
              name: hiitfigure-service # name of the service
            spec:
              selector:
                app: hiitfigure # service manage pods through labels of the pod
              ports:
                - protocol: TCP # type protocol
                  port: 8080 # port of the service
                  targetPort: 8080 # target port of the container in the pod
              type: ClusterIP # type service
            ```
            
        - Tạo `ingress`
            - [https://kubernetes.io/docs/concepts/services-networking/ingress/](https://kubernetes.io/docs/concepts/services-networking/ingress/)
            
            ```yaml
            apiVersion: networking.k8s.io/v1
            kind: Ingress
            metadata:
              name: hiitfigure-ingress # name of the ingress
            spec:
              ingressClassName: nginx 
              rules:
              - http:
                  paths:
                  - path: / # prefix path
                    pathType: Prefix
                    backend:
                      service:
                        name: hiitfigure-service # point to the service
                        port:
                          number: 8080 # port of the service
            ```
            
        - File definition đầy đủ
            
            ```yaml
            apiVersion: v1
            kind: ConfigMap
            metadata:
              name: hiitfigure
              namespace: default
            data:
              MYSQL_DB_HOST: "hiitfigure.random.ap-southeast-1.rds.amazonaws.com"
              MYSQL_DB_PORT: "3306"
              MYSQL_DB_DATABASE: "figurestore"
            ---
            apiVersion: v1
            kind: Secret
            metadata:
              name: hiitfigure
              namespace: default
            type: Opaque
            data:
              MYSQL_DB_USERNAME: aGlpdGZRANDOM==
              MYSQL_DB_PASSWORD: aGlpdGZRANDOM==
              AWS_CREDENTIAL_ACCESS_KEY: QUtJQVNTWDdCQkxEVlRANDOM=
              AWS_CREDENTIAL_SECRET_KEY: NnRzUXIrMW9UdFBxNDBYYUMvaGVlaWI4cEkzOFozOTllSRANDOM==
              MAIL_USERNAME: aGlpdGZpZ3VyZW9mZmljaWFsQGdtYWlsRANDOM==
              MAIL_PASSWORD: ZnFkYXdidmZnZ3VRANDOM==
            ---
            apiVersion: apps/v1
            kind: Deployment
            metadata:
              name: hiitfigure-deployment
              labels:
                app: hiitfigure
            spec:
              replicas: 2
              selector:
                matchLabels:
                  app: hiitfigure
              template:
                metadata:
                  labels:
                    app: hiitfigure
                spec:
                  containers:
                  - name: hiitfigure
                    image: tranvannhan1911/hiitfigure
                    ports:
                    - containerPort: 8080
                    envFrom:
                    - configMapRef:
                        name: hiitfigure
                    - secretRef:
                        name: hiitfigure
            ---
            apiVersion: v1
            kind: Service
            metadata:
              name: hiitfigure-service
            spec:
              selector:
                app: hiitfigure
              ports:
                - protocol: TCP
                  port: 8080
                  targetPort: 8080
              type: ClusterIP
            ---
            apiVersion: networking.k8s.io/v1
            kind: Ingress
            metadata:
              name: hiitfigure-ingress
            spec:
              ingressClassName: nginx
              rules:
              - http:
                  paths:
                  - path: /
                    pathType: Prefix
                    backend:
                      service:
                        name: hiitfigure-service
                        port:
                          number: 8080
            ```
            
        - Apply
            
            ```yaml
            $ kubectl apply -f hiitfigure-deploy.yaml
            ```
            
        - Kết quả
            - `kubectl get all`
                
                ![Untitled](https://i.imgur.com/xhBuXSR.png)
                
            - `kubectl get ingress`
                
                ![Untitled](https://i.imgur.com/Sqxv5wY.png)
                
                ![Untitled](https://i.imgur.com/f3WHTCi.png)
                
3. Tài liệu tham khảo
    - [https://helpex.vn/article/trien-khai-mot-cum-kubernetes-voi-amazon-eks-6096bce8c5512025d4b405d9](https://helpex.vn/article/trien-khai-mot-cum-kubernetes-voi-amazon-eks-6096bce8c5512025d4b405d9)
    - [https://viblo.asia/p/thuc-hanh-set-up-kubernetes-cluster-tren-amazon-web-services-elastic-kubernetes-service-Qbq5QQEz5D8](https://viblo.asia/p/thuc-hanh-set-up-kubernetes-cluster-tren-amazon-web-services-elastic-kubernetes-service-Qbq5QQEz5D8)
    - [https://kubernetes.github.io/ingress-nginx/deploy/#aws](https://kubernetes.github.io/ingress-nginx/deploy/#aws)
    - [https://stackoverflow.com/questions/64965832/aws-eks-only-2-pod-can-be-launched-too-many-pods-error](https://stackoverflow.com/questions/64965832/aws-eks-only-2-pod-can-be-launched-too-many-pods-error)