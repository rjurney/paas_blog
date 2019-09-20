# Using PaaS to Accelerate Enterprise Data Science
As a full-stack machine learning engineer that focuses on delivering new products to market, I’ve often found myself at the intersection of data science, data engineering and dev ops. So it has been with great interest that I’ve followed the rise of data science Platforms as a Service (PaaS). **In this series of posts, I’ll be evaluating different Platforms as a Service (PaaS) and their potential to automate data science operations.** I’m going to explore their capabilities and then automate the setup and execution of code from my forthcoming book *Weakly Supervised Learning* (O’Reilly, 2020) to find the best way for the book’s readers to work through the book.

 In my last book, [Agile Data Science 2.0](https://www.amazon.com/Agile-Data-Science-2-0-Applications/dp/1491960116) (4.5 stars :D), I built [my own platform](https://github.com/rjurney/Agile_Data_Code_2) for readers to run the code using bash scripts, the AWS CLI, [jq](https://stedolan.github.io/jq/), Vagrant and EC2. While this made the book much more valuable for beginners who would otherwise have trouble running the code, it has been extremely difficult to maintain and keep running. Older software falls off the internet and the platform rots. There have been [85 issues](https://github.com/rjurney/Agile_Data_Code_2/issues) on the project, and while many of those have been fixed by reader contributions, it has still taken up much of the time I have to devote to open source software. This time is going to be different.

## DC/OS Data Science Engine
*Note: code for this post is available at [github.com/rjurney/paas_blog](https://github.com/rjurney/paas_blog).*

The first PaaS for data science I’m evaluating is the newly launched DC/OS Data Science Engine. In this post I’ll walk you through my initial experiment with DC/OS (caveat: I’ve used it in the past) and its Data Science Engine using the GUI and then we’ll cover how to automate that same process in a few lines of code. It turns out this is actually simpler than creating the equivalent resources using the AWS CLI, which impressed me. We’ll setup our environment and software prerequisites, initialize a DC/OS cluster using Terraform and the [Universal Installer](https://docs.d2iq.com/mesosphere/dcos/1.13/installing/evaluation/aws/), install the [Data Science Engine package](https://universe.dcos.io/#/package/data-science-engine/version/latest) and then the evaluate the environment by running a model that tags Stack Overflow posts.

A few caveats: we’ll go through how to boot a DC/OS cluster with JupyterLab installed step-by-step, but if you run into trouble you can always refer to the [Universal Installer documentation](https://docs.d2iq.com/mesosphere/dcos/1.13/installing/evaluation/aws/) for DC/OS Terraform problems or the [Data Science Engine documentation](https://docs.d2iq.com/mesosphere/dcos/services/data-science-engine/1.0.0/quick-start/) for problems deploying that service.

### Why the DC/OS Data Science Engine?

It has become fairly easy to setup a Jupyter Notebook in any given cloud environment like Amazon Web Services (AWS), Google Cloud Platform (GCP) and Azure for an individual data scientist to work. For startups and small data science teams, this is a good solution. Nothing stays up to be maintained and notebooks can be saved in Github for persistence and sharing.

For large enterprises, things are not so simple. At this scale, temporary environments on transitory assets across multiple clouds can create chaos rather than order, as environments and modeling become irreproducible. Enterprises work across multiple clouds and on premises, have particular access control and authentication requirements, and need to provide access to internal resources for data, source control, streaming and other services.

*For these organizations the DC/OS Data Science Engine offers a unified system offering the Python ML stack, Spark, Tensorflow and other DL frameworks, including [TensorFlowOnSpark](https://github.com/yahoo/TensorFlowOnSpark) to enable distributed multi-node, multi-GPU model training.* Its a pretty compelling setup that works out of the box and can end much frustration and complexity for larger data science teams and companies.

## Software and Platform Prerequisites
The [DC/OS Universal Installer](https://docs.d2iq.com/mesosphere/dcos/1.13/installing/evaluation/aws/) can run from Linux, Mac OS X and Windows. For all platforms you will need [Python](https://www.python.org/about/gettingstarted/), [pip](https://pip.pypa.io/en/stable/), the [AWS Command Line Interface (CLI)](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-welcome.html) and [Terraform](https://www.terraform.io/intro/index.html).  You probably have Python installed if you’re testing out the Data Science Engine, but if not we’ll install [Anaconda Python](https://www.anaconda.com/distribution/). 

**You will also need to authorize 5 GPU instances in the region in which you will run DC/OS Data Science Engine (in this post we use `us-west-2`). Let’s take it step by step.**

### Installing Anaconda Python

![](images/anaconda_logo.png)

If you already have Python installed on your machine, there is no need to install Anaconda Python. If you don’t, I recommend Anaconda Python as it is easy to install, sits in your home directory, and has the excellent conda package manager.

Download Anaconda Python 3.X for your platform [here](https://www.anaconda.com/distribution/#download-section), then follow the instructions for installation for [Linux](https://docs.anaconda.com/anaconda/install/linux/), [Mac OS X](https://docs.anaconda.com/anaconda/install/mac-os/) and [Windows](https://docs.anaconda.com/anaconda/install/windows/).

### AWS Authentication via Installing and Configuring the Amazon Web Services CLI

There are two ways of setting up AWS access for  the [Terraform AWS provider](https://www.terraform.io/docs/providers/aws/index.html): via the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html#cli-quick-configuration) or by editing *paas_blog/dcos/terraform/terraform.tf*.

![](images/aws_cli_logo.png)

First we’ll setup our AWS credentials for the to use. To , use the PyPI [awscli package](https://pypi.org/project/awscli/):

```bash
# Install using conda
conda install -c conda-forge awscli

# OR...

# Install using pip
pip install awscli --upgrade --user
```

Now [setup](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) your AWS credentials, using your Access Key ID and Secret Access Key, which you can find in the [IAM console](https://console.aws.amazon.com/iam/home#/security_credentials). You can alter the region to your own default. Terraform’s AWS module will use these credentials by default. They’re stored in the `~/.aws/` directory.

```bash
aws configure

AWS Access Key ID [None]: **AKIAIOSFODNN7EXAMPLE**
AWS Secret Access Key [None]: **wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY**
Default region name [None]: **us-west-2**
Default output format [None]: **json**
```

Now verify the setup worked:

```bash
aws sts get-caller-identity
```

You should see something like this:

```json
{
    "UserId": "123456789101",
    "Account": "109876543210",
    "Arn": "arn:aws:iam::123456789101:root"
}
```

### AWS Authentication via Editing terraform.tf

You can explicitly setup AWS authentication by editing *paas_blog/dcos/terraform/terraform.tf* to include your credentials where the AWS provider is called. Simply add your access key/secret key and default region.

```
provider "aws" {
	access_key = "foo"
	secret_key = "bar"
	region     = "us-west-2"
}
```

### Installing Terraform

![](images/terraform_logo.png)

> Terraform enables users to define and provision a datacenter infrastructure using a high-level configuration language known as Hashicorp Configuration Language (HCL).  
>   
> —Wikipedia, Terraform (software)  

Ubuntu users can install Terraform 11.x like so:

```bash
wget https://releases.hashicorp.com/terraform/0.11.14/terraform_0.11.14_linux_386.zip
sudo apt-get install unzip
unzip terraform_0.11.14_linux_386.zip
sudo mv terraform /usr/local/bin/
```

On a Mac, use [Homebrew](https://brew.sh/):

```bash
brew unlink terraform || true
brew install tfenv
tfenv install 0.11.14
```

Windows users can use [Chocolatey](https://chocolatey.org/):

```bash
choco install terraform --version 0.11.14 -y
```

Verify that terraform works:

```bash
terraform --version
```

You should see:

```bash
Terraform v0.11.14
```

Now we’re good to go! Ignore any message about upgrading. Now that Terraform is installed, we’re ready to configure and launch our DC/OS cluster on AWS.

### Authorizing AWS Service Limits for GPU Instances

![](images/aws_gpu.png)

[AWS Service Limits](https://docs.aws.amazon.com/general/latest/gr/aws_service_limits.html) define how many AWS resources you can use in any given region. We’ll be booting 5 p3.2xlarge GPU instances as private agents for our DC/OS cluster where notebooks will run. **The default service quota for the p3.2xlarge instance type is 0. In order to run this tutorial, you will need to request that AWS increase this to 5 or more.**

You can do so by logging into the AWS Web Console and visiting the Service Quotas console here: https://us-west-2.console.aws.amazon.com/servicequotas/home?region=us-west-2#!/services/ec2/quotas (you can substitute your preferred [AWS region](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html#concepts-available-regions) in the url, just be sure to substitute it in _both_ places it appears in the url). Search for `p3.2xlarge` in the search box and click the orange `Request quota increase` button to the right.

![](images/service_quotas_increase_selected.png)

Enter `5` into the `Change quota value` field. Then click the orange `Request` button at bottom right.

![](images/increase_gpu_quota_popup.png)

Now you will have to wait 12-48 hours for the request to be approved. I have a basic AWS account and when I request an increase in the afternoon and it is approved the next morning. If you need to speed things up, you can go to the AWS [Support Center](https://console.aws.amazon.com/support/home?region=us-west-2) and request a call with an agent. They can usually accelerate things quite a bit.

## DC/OS on AWS with the Universal Installer

![](images/dcos_logo.png)

There is good [documentation](https://docs.d2iq.com/mesosphere/dcos/1.13/installing/evaluation/aws/) for the DC/OS Universal Installer on [d2iq.com](http://docs.d2iq.com), but I’ll provide code that ‘just works’ as part of this post. We’ll be using Terraform to configure and launch our cluster, then we’ll install the [Data Science Engine package](https://universe.dcos.io/#/package/data-science-engine/version/latest) and get down to work with JupyterLab!

**Change directory to the [Github project](https://github.com/rjurney/paas_blog) subdirectory [*paas_blog/dcos/terraform*](https://github.com/rjurney/paas_blog/tree/master/dcos/terraform) for the remainder of the tutorial.**

### Configuring DC/OS

The first step in configuring out DC/OS cluster is to create a cluster-specific ssh key. We’ll call this key *my_key.pub*. 

```bash
ssh-keygen -t rsa -f my_key
```

Hit enter twice to create the key without a password.

```bash
Generating public/private rsa key pair.
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in my_key.
Your public key has been saved in my_key.pub.
The key fingerprint is:
SHA256:OCOfrIzrTznoMqKOJ2VD2r6YPQp8jFFKIbe/BDyhWuI rjurney@Hostname.local
The key's randomart image is:
+---[RSA 2048]----+
|..o              |
|.+.o             |
|o.*.             |
|+o++   .         |
|.E  + + S        |
|o Oo * +         |
|.*.+= +          |
|B==+ o           |
|XOB=+            |
+----[SHA256]-----+
```

We need to change the permissions of *my_key* to be readable only to our user, *0600*, or later ssh will complain.

```bash
chmod 0600 ./my_key
```

Now run *ssh-agent* if it isn’t running and add the key to the agent. 

*Note: without this step, you will get ssh errors when you create the cluster. See section Common Errors below.*

```bash
eval "$(ssh-agent -s)"
ssh-add ./my_key
```

Now verify the key has been added:

```bash
ssh-add -l
```

Which should show:

```bash
2048 SHA256:1234567891234567891234567891234567891234567 ./my_key (RSA)
```

### Creatings a Superuser Password Hash via a Script

Now we’ll create a superuser password hash file for the cluster using Python’s [hashlib](https://docs.python.org/3/library/hashlib.html) module. We’ll call ours *dcos_superuser_password_hash*.  

I’ve created a command line script that will generate, print and write a password hash to disk called *paas_blog/dcos/terraform/generate_password_hash.py*.

```bash
usage: generate_password_hash.py [-h] PASSWORD

Generate an SHA512 password hash for the given password

positional arguments:
  PASSWORD    A password to generate a SHA512 hash of

optional arguments:
  -h, --help  show this help message and exit
```

To run it, simply run:

```bash
python ./generate_password_hash.py my_password
```

You should see output something like this:

```bash
Wrote SHA512 digest: '1234567891011121314151617181920212223242526...' for password 'my_password' to ./dcos_superuser_password_hash
```

Verify the write to the file *dcos_superuser_password_hash* was successful:

```bash
cat dcos_superuser_password_hash
```

### Creating a Superuser Password Hash in Python

To create the hash manually, open a Python shell (consider using [ipython](https://ipython.org/)):

```bash
python
```

```python
import hashlib

with open('dcos_superuser_password_hash', 'w') as f:
	m = hashlib.sha512('my_password'.encode())
	f.write( m.hexdigest() )
```

Change the password hash’s permissions to be readable only to your user, *0600*, or the DC/OS CLI will complain:

```bash
chmod 0600 ./dcos_superuser_password_hash
```

Verify the password has saved successfully:

```bash
cat dcos_superuser_password_hash
```

```
dda8c3468860dcb24e228ab8ee44208d43eb2f5fd2a3a538bafbd8860dcb24e228ab8ee44208d43eb2f5a2f8b143eb2f5a2f8b17eccc87ffe79d8459e2df294fb01
```

### Creating a License File - (Enterprise Edition Only)

As we’ll be using the open version of DC/OS, I created an empty *license.txt* file via `touch license.txt`. It needs to exist, but it can be empty. It is already committed to Github, so for the open version of DC/OS, you don’t need to create it once you check out the [GitHub project](https://github.com/rjurney/paas_blog). If you’re using the Enterprise Edition, you’ll need to put your actual license in *license.txt*.

### Configuring Our DC/OS Cluster

I’ve edited the file *paas_blog/dcos/terraform/desired_cluster_profile.tfvars* to personalize the superuser account name, load the superuser password hash from the password hash file we created above, to specify an empty license string and point at an empty *license.txt* file. The DC/OS variant is set to *open*, the DC/OS version to *1.13.3*, we’ll use an *m5.xlarge* for our bootstrap instance type and we’ll use *p3.2xlarge* instances to run JupyterLab. We set the number of GPU agents to 5, which is enough to run Spark and JupyterLab. Finally, we specify the public key we generated earlier, *my_key.pub*. Remember to use the public and not private key.

*Note: you can find the latest version of DC/OS on the [releases page](https://dcos.io/releases/), and you can find the latest version of the Universal Installer by clicking on *tags* on its [Github repo](https://github.com/dcos-terraform/terraform-aws-dcos). If you run into problems, use the highest *0.2.x* tag available by editing the *version* key in *terraform.tf*.

```
cluster_owner                = "rjurney"
dcos_superuser_password_hash = "${file("dcos_superuser_password_hash")}"
dcos_superuser_username      = "rjurney"
dcos_license_key_contents    = ""
dcos_license_key_file        = "./license.txt"
dcos_version                 = "1.13.4"
dcos_variant                 = "open"
bootstrap_instance_type      = "m5.xlarge"
gpu_agent_instance_type      = "p3.2xlarge"
num_gpu_agents               = "5"
ssh_public_key_file          = "./my_key.pub"
```

Note: If you’re using the _enterprise edition_ of DC/OS, you’ll need to fill in `dcos_license_key_contents`, which we’ll leave blank for the open variant.  You’ll also want to change the configuration such that `dcos_variant = “ee”`.

### Initializing Terraform

First we need to [initialize](https://www.terraform.io/docs/commands/init.html) Terraform with all the modules we’ll be using:

```bash
terraform init -upgrade
```

You should see:

```bash
Upgrading modules...
<list of modules>
Initializing provider plugins...
<list of plugins>

Terraform has been successfully initialized!
```

### Generating a Terraform Plan

Now we need to use the variables we defined in *paas_blog/dcos/terraform/desired_cluster_profile.tfvars* to generate a [plan of action](https://www.terraform.io/docs/commands/plan.html) for Terraform to carry out. We’ll save the plan to *paas_blog/dcos/terraform/plan.out*.

```bash
terraform plan -var-file desired_cluster_profile.tfvars -out plan.out
```

You should see a lot of output with no errors, ending with:

```bash
Plan: 75 to add, 3 to change, 0 to destroy.

------------------------------------------------------------------------

This plan was saved to: plan.out

To perform exactly these actions, run the following command to apply:
    terraform apply "plan.out"
```

Now we have a plan for Terraform to create our DC/OS cluster in *plan.out*, which is binary and can’t be inspected very easily.

### Booting our DC/OS Cluster

Now that we have a plan that includes our custom variables, we don’t need to include them again in the apply command. We can just follow the directions at the end of the output of the *plan* command. Note that we don’t use `--var-file` with apply, because plan has inserted our variables into the plan.

```bash
terraform apply plan.out
```

This command can take as long as 15 minutes to execute as there is a delay in initializing a sequence of AWS resources and then executing commands to initialize the services on EC2 instances. You should see a lot of output, beginning with:

```bash
module.dcos.module.dcos-infrastructure.module.dcos-lb.module.dcos-lb-masters.module.masters.tls_private_key.selfsigned: Creating...
<lots more stuff>
```

If you see any errors, the best thing is to destroy the cluster and try again. Occasionally timing issues in delayed initialization of AWS resources can cause boot problems.

### Destroying our DC/OS Cluster

When you’re done with the cluster, if there is an error, or if you need to recreate it, you can destroy all associated resources with the following command. Note that we do need to use `—var-file` with `destroy`.

```bash
terraform destroy --auto-approve --var-file desired_cluster_profile.tfvars
```

This may take a second, as there are many resources to remove. Once the destroy is complete you are free to plan and apply again.

## Logging in to our DC/OS Cluster
The final output of the `terraform apply` command gives us the address of the master node to connect to and should look something like this:

```bash
Apply complete! Resources: 75 added, 0 changed, 0 destroyed.

Outputs:

masters-ips = [
    54.XX.XXX.XXX
]
public-agents-loadbalancer = ext-jupyter-gpu-12a9-abcdefg1234.elb.us-west-2.amazonaws.com
```

Open the master ip address in a browser and you should see a login window. Note that the only IP authorized to connect to this machine is your source IP.

![](images/dcos_login.png)

Select your authentication method - I use Google. Once you authenticate, it will return you to the home page.

## Installing the Data Science Engine Service

![](images/dcos_home.png)

On the left hand menu, fourth down from the top and circled in orange in this image, is the *Catalog* item. Click it and the DC/OS Service Menu will come up. When I did so, the *data-science-engine* service was visible in the second row from the top, but if it isn’t use the search box at top left to find it.

![](images/dcos_catalog.png)

Click on the *data-science-engine* service and its service page will come up. Click *Review & Run* to install the service.

![](images/dcos_service_install.png)

This will bring up a window where you can edit the configuration of the Data Science Engine. You need to name the cluster using letters and dashes, but it doesn’t matter what you name it, except that names are unique. Since we’re using *p3.2xlarge* instances, configure the service to use **58GB of RAM and 8 CPUs**. Check the Nvidia GPU Allocation Configuration Enabled checkbox and type 1 for the number of GPUs.

![](images/dcos_service_config_50.png)

Click the purple *Review & Run* button at top right. This will take you to the final review screen. Click the purple *Run Service* button at top right. 

*Note that you can download the service configuration as JSON to run later with the DC/OS CLI, enabling you to automate the deployment of the service, for example as part of your continuous integration system. To do so click Download Config.*

![](images/dcos_service_review_50.png)

You should see a popup announcing the successful launch of the system. Click *Open Service*.

![](images/dcos_service_popup.png)

This will take you to the Data Science Engine service page. At first the page’s status will say the service is loading, but soon the Health swatch will become green and the Status will say *Running*. 

![](images/dcos_service_page.png)

## Using the Data Science Engine
Now click on the text *Services* where it says *Services > data-science-engine* at the top of the white area of the screen. This will take you to the service listing. You should see *data-science-engine* listed. Click on the launch icon circled in orange in the image below. This will open a connection with JupyterLab. The default Jupyter password is *jupyter*, but you can set it using the service configuration window we used to launch the service.

![](images/dcos_services_page.png)

Once you enter the default Jupyter password of *jupyter* (you can change it in *desired_cluster_profile.tfvars*), you will see the homepage of JupyterLab. The first page load can take a little while. Tada!

![](images/jupyter_lab_home.png)

## Exercising our GPU with some Natural Language Processing
Now that we’ve booted the cluster and service, let’s exercise it by training a neural network to tag StackOverflow questions. We treat this as a multi-class, multi-label problem. The training data has been balanced by upsampling the complete dump of questions that have at least one answer, one vote and have at least one tag occurring more than 2,000 times. It is about 600MB. This dataset was [previously computed](https://github.com/rjurney/deep_products/blob/master/code/stackoverflow/get_questions.spark.py) and the files can be found in the *paas_blog/data* directory of the Github repo.

You can view the Jupyter Notebook with the code we’ll be running from Github at [github.com/rjurney/paas_blog/DCOS_Data_Science_Engine.ipynb](https://github.com/rjurney/paas_blog/blob/master/DCOS_Data_Science_Engine.ipynb). We’ll be opening it using the JupyterLab Github interface, but if you like you can paste its content block-by-block into a new Python 3 notebook.

### Loading the Tutorial Notebook

JupyterLab’s Github module is super awesome and makes loading the tutorial notebook easy. Click on the Github icon on the far left of the screen, between the file and running man icons. Enter *rjurney* where it says *<Edit User>*.

![](images/jupyter_lab_github.png)

My public Github projects will come up. Select *paas_blog* and then double click on the *DCOS_Data_Science_Engine.ipynb* Jupyter notebook to open it. It uses data on S3, so you shouldn’t have to download any data.

![](images/jupyter_lab_github_project.png)

### Verifying GPU Support

The first thing to do is to verify that our JupyterLab Python environment on our Data Science Engine EC2 instance is properly configured to work with its onboard GPU. We use `tensorflow.test.is_gpu_available` and `tensorflow.compat.v2.config.experimental.list_physical_devices` to verify the GPUs are working with Tensorflow.

```python
gpu_avail = tf.test.is_gpu_available(
    cuda_only=False,
    min_cuda_compute_capability=None
)
print(f'1 or more GPUs is available: {gpu_avail}')

from tensorflow.python.client import device_lib
local_devices = device_lib.list_local_devices()
gpu = local_devices[3]
print(f"{gpu.name} is a {gpu.device_type} with {gpu.memory_limit / 1024 / 1024 / 1024:.2f}GB RAM")
```

You should see something like:

```python
1 or more GPUs is available: True
/device:GPU:0 is a GPU with 10.22GB RAM
```

### Loading the Data from S3

You can load the data for this tutorial using *pandas.read_parquet*.

```python
# Load the Stack Overflow questions right from S3
s3_parquet_path = f's3://{BUCKET}/08-05-2019/Questions.Stratified.Final.2000.parquet'
s3_fs = s3fs.S3FileSystem()

# Use pyarrow.parquet.ParquetDataset and convert to pandas.DataFrame
posts_df = ParquetDataset(
    s3_parquet_path,
    filesystem=s3_fs,
).read().to_pandas()

posts_df.head(3)
```

Now we load the indexes to convert back and forth between label indexes and text tags. We’ll use these to view the actual resulting tags predicted at the end of the tutorial.

```python
# Get the tag indexes
s3_client = boto3.resource('s3')

def json_from_s3(bucket, key):
    """Given a bucket and key for a JSON object, return the parsed object"""
    obj = s3_client.Object(bucket, key)
    obj.get()['Body'].read().decode('utf-8')
    json_obj = json.loads(obj.get()['Body'].read().decode('utf-8'))
    return json_obj


tag_index = json_from_s3(BUCKET, '08-05-2019/tag_index.2000.json')
index_tag = json_from_s3(BUCKET, '08-05-2019/index_tag.2000.json')

list(tag_index.items())[0:5], list(index_tag.items())[0:5]
```

Then we verify the number of records loaded:

```python
print(
    '{:,} Stackoverflow questions with a tag having at least 2,000 occurrences'.format(
        len(posts_df.index)
    )
)
```

```
1,554,788 Stackoverflow questions with a tag having at least 2,000 occurrences
```

### Preparing the Data

We need to join the previously tokenized text back into a string for use in a Tokenizer, which provides useful properties. In addition, making the number of documents a multiple of batch size is a requirement for Tensorflow/Keras to split work among multiple GPUs and to use certain models such as Elmo.

```python
import math

BATCH_SIZE = 64
MAX_LEN = 200
TOKEN_COUNT = 10000
EMBED_SIZE = 50
TEST_SPLIT = 0.2

# Convert label columns to numpy array
labels = posts_df[list(posts_df.columns)[1:]].to_numpy()

# Training_count must be a multiple of the BATCH_SIZE times the MAX_LEN
highest_factor = math.floor(len(posts_df.index) / (BATCH_SIZE * MAX_LEN))
training_count = highest_factor * BATCH_SIZE * MAX_LEN
print(f'Highest Factor: {highest_factor:,} Training Count: {training_count:,}')

# Join the previously tokenized data for tf.keras.preprocessing.text.Tokenizer to work with
documents = []
for body in posts_df[0:training_count]['_Body'].values.tolist():
    words = body.tolist()
    documents.append(' '.join(words))

labels = labels[0:training_count]

# Conserve RAM
del posts_df
gc.collect()

# Lengths for x and y match
assert( len(documents) == training_count == labels.shape[0] )
```

You should see:

```
Highest Factor: 121 Training Count: 1,548,800
```

### Pad the Sequences

The data has already been truncated to 200 words per post but the tokenization using the top 10K words reduces this to below 200 in some documents. If any documents vary from 200 words, the data won't convert properly into a *numpy* matrix below. 

In addition to converting the text to numeric sequences with a key, Keras’ *Tokenizer* class is handy for producing the final results of the model via the [*keras.preprocessing.text.Tokenizer.sequences_to_texts*](https://keras.io/preprocessing/text/#tokenizer) method. Then we use Keras’ [*keras.preprocessing.sequence.pad_sequences*](https://keras.io/preprocessing/sequence/#pad_sequences) method and check the output to ensure the sequences are all 200 items long or they won’t convert properly into a matrix. The string `__PAD__` has been used previously to pad the documents, so we reuse it here.

```python
from tf.keras.preprocessing.text import Tokenizer
from tf.keras.preprocessing.sequence import pad_sequences

tokenizer = Tokenizer(
    num_words=TOKEN_COUNT,
    oov_token='__PAD__'
)
tokenizer.fit_on_texts(documents)
sequences = tokenizer.texts_to_sequences(documents)

padded_sequences = pad_sequences(
    sequences,
    maxlen=MAX_LEN,
    dtype='int32',
    padding='post',
    truncating='post',
    value=1
)

# Conserve RAM
del documents
del sequences
gc.collect()

print( max([len(x) for x in padded_sequences]), min([len(x) for x in padded_sequences]) )
assert( min([len(x) for x in padded_sequences]) == MAX_LEN == max([len(x) for x in padded_sequences]) )

padded_sequences.shape
```

### Split into Test/Train Datasets

We need one dataset to train with and one separate dataset to test and validate our model with.  The oft used [sklearn.model_selection.train_test_split](https://scikit-learn.org/stable/modules/generated/sklearn.model_selection.train_test_split.html) makes it so.

```python
from sklearn.model_selection import train_test_split

X_train, X_test, y_train, y_test = train_test_split(
    padded_sequences,
    labels,
    test_size=TEST_SPLIT,
    random_state=1337
)

# Conserve RAM
del padded_sequences
del labels
gc.collect()

assert(X_train.shape[0] == y_train.shape[0])
assert(X_train.shape[1] == MAX_LEN)
assert(X_test.shape[0] == y_test.shape[0]) 
assert(X_test.shape[1] == MAX_LEN)
```

### Compute Class Weights

Although there has already been filtering and up-sampling of the data to restrict it to a sample of questions with at least one tag that occurs more than 2,000 times, there are still uneven ratios between common and uncommon labels. Without class weights, the most common label will be much more likely to be predicted than the least common. Class weights will make the loss function consider uncommon classes more than frequent ones.

```python
train_weight_vec = list(np.max(np.sum(y_train, axis=0))/np.sum(y_train, axis=0))
train_class_weights = {i: train_weight_vec[i] for i in range(y_train.shape[1])}

sorted(list(train_class_weights.items()), key=lambda x: x[1])[0:10]
```

### Train a Classifier Model to Tag Stack Overflow Posts

Now we’re ready to train a model to classify/label questions with tag categories. The model is based on [Kim-CNN](https://arxiv.org/abs/1408.5882), a commonly used convolutional neural network for sentence and document classification. We use the functional API and we’ve heavily parametrized the code so as to facilitate experimentation. 

```python
from tensorflow.keras.initializers import RandomUniform
from tensorflow.keras.callbacks import ReduceLROnPlateau, EarlyStopping, ModelCheckpoint
from tensorflow.keras.layers import (
    Dense, Activation, Embedding, Flatten, MaxPool1D, GlobalMaxPool1D, Dropout, Conv1D, Input, concatenate
)
from tensorflow.keras.losses import binary_crossentropy
from tensorflow.keras.models import Model
from tensorflow.keras.optimizers import Adam

FILTER_LENGTH       = 300
FILTER_COUNT        = 128
FILTER_SIZES        = [3, 4, 5]
EPOCHS              = 4
ACTIVATION          = 'selu'
CONV_PADDING        = 'same'
EMBED_SIZE          = 50
EMBED_DROPOUT_RATIO = 0.1
CONV_DROPOUT_RATIO  = 0.1
LOSS                = 'binary_crossentropy'
OPTIMIZER           = 'adam'
```

In Kim-CNN, we start by encoding the sequences using an *Embedding*, followed by a *Dropout* layer to reduce overfitting. Next we split the graph into multiple *Conv1D* layers with different widths, each followed by *MaxPool1D*. These are joined by concatenation and are intended to characterize patterns of different size sequence lengths in the documents. There follows another *Conv1D*/*GlobalMaxPool1D* layer to summarize the most important of these patterns. This is followed by flattening into a *Dense* layer and then on to the final *sigmoid* output layer. Otherwise we use *selu* throughout.

```python
padded_input = Input(
    shape=(X_train.shape[1],), 
    dtype='int32'
)

# Create an embedding with RandomUniform initialization
emb = Embedding(
    TOKEN_COUNT, 
    EMBED_SIZE, 
    input_length=X_train.shape[1],
    embeddings_initializer=RandomUniform()
)(padded_input)
drp = Dropout(EMBED_DROPOUT_RATIO)(emb)

# Create convlutions of different kernel sizes
convs = []
for filter_size in FILTER_SIZES:
    f_conv = Conv1D(
        filters=FILTER_COUNT,
        kernel_size=filter_size,
        padding=CONV_PADDING,
        activation=ACTIVATION
    )(drp)
    f_pool = MaxPool1D()(f_conv)
    convs.append(f_pool)

l_merge = concatenate(convs, axis=1)
l_conv = Conv1D(
    128,
    5,
    activation=ACTIVATION
)(l_merge)
l_pool = GlobalMaxPool1D()(l_conv)
l_flat = Flatten()(l_pool)
l_drop = Dropout(CONV_DROPOUT_RATIO)(l_flat)
l_dense = Dense(
    128,
    activation=ACTIVATION
)(l_drop)
out_dense = Dense(
    y_train.shape[1],
    activation='sigmoid'
)(l_dense)

model = Model(inputs=padded_input, outputs=out_dense)
```

Next we compile our model. We use a variety of metrics, because no one metric summarizes model performance, and we need to drill down into the true and false positives and negatives. We also use the *ReduceLROnPlateau*, *EarlyStopping* and *ModelCheckpoint* callbacks to improve performance once we hit a plateau, then to stop early, and to persist only the very best model in terms of the validation categorical accuracy. 

Categorical accuracy is the best fit for gauging our model’s performance because it gives points for each row separately for each class we’re classifying. This means that if we miss one, but get the others right, this is a great result. With binary accuracy, the entire row is scored as incorrect.

Then it is time to fit the model. We give it the class weights we computed earlier.

```python
model.compile(
    optimizer=OPTIMIZER,
    loss=LOSS,
    metrics=[
        tf.keras.metrics.CategoricalAccuracy(),
        tf.keras.metrics.Precision(),
        tf.keras.metrics.Recall(),
        tf.keras.metrics.Accuracy(),
        tf.keras.metrics.TruePositives(),
        tf.keras.metrics.FalsePositives(),
        tf.keras.metrics.TrueNegatives(),
        tf.keras.metrics.FalseNegatives(),
    ]
)
model.summary()

callbacks = [
    ReduceLROnPlateau(
        monitor='val_categorical_accuracy',
        factor=0.1,
        patience=1,
    ), 
    EarlyStopping(
        monitor='val_categorical_accuracy',
        patience=2
    ), 
    ModelCheckpoint(
        filepath='kim_cnn_tagger.weights.hdf5',
        monitor='val_categorical_accuracy',
        save_best_only=True
    ),
]

history = model.fit(X_train, y_train,
                    class_weight=train_class_weights,
                    epochs=EPOCHS,
                    batch_size=BATCH_SIZE,
                    validation_data=(X_test, y_test),
                    callbacks=callbacks)
```

### Load the Best Model from Training Epochs

Because we used `ModelCheckpoint(save_only_best=True)`, the best epoch in terms of `CategoricalAccuracy` is what was saved. We want to use that instead of the last epoch's model, which is what is stored in `model` above. So we load the file before evaluating our model.

```python
model = tf.keras.models.load_model('kim_cnn_tagger.weights.hdf5')
metrics = model.evaluate(X_test, y_test)
```

### Parse and Print Final Metrics

Metrics include names like *precision_66* which aren't consistent between runs. We fix these to cleanup our report on training the model. We also add an f1 score, then make a DataFrame to display the log. This could be extended in repeat experiments.

```python
def fix_metric_name(name):
    """Remove the trailing _NN, ex. precision_86"""
    if name[-1].isdigit():
        repeat_name = '_'.join(name.split('_')[:-1])
    else:
        repeat_name = name
    return repeat_name

def fix_value(val):
    """Convert from numpy to float"""
    return val.item() if isinstance(val, np.float32) else val

def fix_metric(name, val):
    repeat_name = fix_metric_name(name)
    py_val = fix_value(val)
    return repeat_name, py_val

log = {}
for name, val in zip(model.metrics_names, metrics):
    repeat_name, py_val = fix_metric(name, val)
    log[repeat_name] = py_val
log.update({'f1': (log['precision'] * log['recall']) / (log['precision'] + log['recall'])})

pd.DataFrame([log])
```

### Plot the Epoch Accuracy

We want to know the performance at each epoch so that we don't train needlessly large numbers of epochs. 

```python
%matplotlib inline

new_history = {}
for key, metrics in history.history.items():
    new_history[fix_metric_name(key)] = metrics

import matplotlib.pyplot as plt

viz_keys = ['val_categorical_accuracy', 'val_precision', 'val_recall']
# summarize history for accuracy
for key in viz_keys:
    plt.plot(new_history[key])
plt.title('model accuracy')
plt.ylabel('metric')
plt.xlabel('epoch')
plt.legend(viz_keys, loc='upper left')
plt.show()

# summarize history for loss
plt.plot(history.history['loss'])
plt.plot(history.history['val_loss'])
plt.title('model loss')
plt.ylabel('loss')
plt.xlabel('epoch')
plt.legend(['train', 'test'], loc='upper left')
plt.show()
```

### Check the Actual Prediction Outputs

It is not enough to know theoretical performance. We need to see the actual output of the tagger at different confidence thresholds.

```python
TEST_COUNT = 1000

X_test_text = tokenizer.sequences_to_texts(X_test[:TEST_COUNT])

y_test_tags = []
for row in y_test[:TEST_COUNT].tolist():
    tags = [index_tag[str(i)] for i, col in enumerate(row) if col == 1]
    y_test_tags.append(tags)

CLASSIFY_THRESHOLD = 0.5

y_pred = model.predict(X_test[:TEST_COUNT])
y_pred = (y_pred > CLASSIFY_THRESHOLD) * 1

y_pred_tags = []
for row in y_pred.tolist():
    tags = [index_tag[str(i)] for i, col in enumerate(row) if col > CLASSIFY_THRESHOLD]
    y_pred_tags.append(tags)
```

Lets look at the sentences with the actual labels and the predicted labels in a *DataFrame*:

```python
prediction_tests = []
for x, y, z in zip(X_test_text, y_pred_tags, y_test_tags):
    prediction_tests.append({
        'Question': x,
        'Predictions': ' '.join(sorted(y)),
        'Actual Tags': ' '.join(sorted(z))
    })

pd.DataFrame(prediction_tests)
```

We can see from these three records that the model is doing fairly well. This tells a different story than performance metrics alone. It is so strange that most machine learning examples just compute performance and don’t actually employ the `predict()` method! At the end of the day statistical performance is irrelevant and what matters is the real world performance - which is not contained in simple summary statistics!

![](images/jupyter_results.png)


## Automating DC/OS Data Science Engine Setup
That covers how you use the platform manually, but this is about PaaS automation. So how do we speed things up?

DC/OS’s graphical user interface and CLI together enable easy access to JupyterLab via the Data Science Engine for all kinds of users: non-technical managers trying to view a report in a notebook and dev ops/data engineers looking to automate a process. If the manual GUI process seems involved, we can automate it in a few lines once we have the service configuration as a JSON file by launching the DC/OS cluster via Terraform commands, getting the cluster address from Terraform,then using the DC/OS CLI to authenticate with the cluster and run the service. 

*Note: check out the [Github page](https://github.com/dcos/dcos-cli) for the DC/OS CLI for more information on how it works.*

### Installing the DC/OS CLI

The DC/OS CLI is not required to boot a cluster with Terraform and install the Data Science Engine manually in the UI, but it is required to automate the process. If you run into trouble, check out the [CLI install documentation](https://docs.d2iq.com/mesosphere/dcos/1.12/cli/install/). You will need [curl](https://curl.haxx.se/).

```bash
# Optional: make a /usr/local/bin if it isn't there. Otherwise change the install path.
[ -d usr/local/bin ] || sudo mkdir -p /usr/local/bin

# Download the executable
curl https://downloads.dcos.io/binaries/cli/linux/x86-64/dcos-1.13/dcos -o dcos

```

Note that you can also download the CLI using the commands that print when you click on the top right dropdown titled *jupyter-gpu-xxxx* (or whatever you named your cluster) and then click on the Install CLI button inside the orange box below.

![](images/dcos_download_cli.png)

A popup will appear with installation code for Windows, OS X and Linux. Copy/paste that code into a terminal to complete the install.

![](images/dcos_cli_install_box.png)

Now, if you run `dcos` you should see the following:

```bash
Usage:
  dcos [command]

Commands:
  auth
      Authenticate to DC/OS cluster
  cluster
      Manage your DC/OS clusters
  config
      Manage the DC/OS configuration file
  help
      Help about any command
  plugin
      Manage CLI plugins

Options:
  --version
      Print version information
  -v, -vv
      Output verbosity (verbose or very verbose)
  -h, --help
      Show usage help

Use "dcos [command] --help" for more information about a command.
````

### Manually Exporting the Package Configuration Using the GUI

To automatically install the Data Science Engine package, we first need to get its configuration as a JSON file. This can be done in two ways: via the GUI or via the DC/OS CLI or via the Terraform CLI. We’ll cover both methods.

![](images/dcos_service_config_download.png)

Using the GUI, we can get the JSON for the package configuration by downloading it from the *Configuration* tab of the *data-science-engine* service page. Click *Download Config* in purple at the top right under the line.

By the way, you can edit the Data Science Engine service by clicking the purple *Edit* button at top right. You can use the menu or JSON editor to change the service - increase RAM or GPUs for example - and it will automatically redeploy with that configuration.

![](images/dcos_service_json_50.png)

### Authenticating the DC/OS CLI with the Cluster

To use the CLI, we need to authenticate with the cluster. This can be done via Google, or via a username or other method that suits your organization. To do so, first we need the server address from Terraform. We can extract the cluster master IP address(es) via `terraform output -json` and the [*jq*](https://stedolan.github.io/jq/) json utility. Once we have that, we can use whatever method we prefer, including Google, to authenticate. This could also be a username to facilitate automation.

```bash
# Get the cluster address from Terraform's JSON output and Authenticate CLI to Cluster
export CLUSTER_ADDRESS=`terraform output -json | jq -r '.["masters-ips"].value[0]'`
dcos cluster setup http://$CLUSTER_ADDRESS # add whatever arguments you need for automated authentication
```

Check the [documentation](https://docs.d2iq.com/mesosphere/dcos/1.13/cli/command-reference/dcos-cluster/dcos-cluster-setup/) for `dcos cluster setup` for information on different methods of authentication.

### Exporting the Package Configuration Using the CLI

Once we’ve authenticated, we can use the CLI to generate the package configuration file for later reuse.

For Mac OS X the flag for the command *base64* is a capital `-D`:

```bash
dcos marathon app show data-science-engine | jq -r .labels.DCOS_PACKAGE_OPTIONS | base64 -D | jq > my-data-science-engine.json
```

For Linux the flag is a lowercase `-d`:

```bash
dcos marathon app show data-science-engine | jq -r .labels.DCOS_PACKAGE_OPTIONS  | base64 -d | jq > my-data-science-engine.json
```

Note that the exported options cover every single option, which isn’t ideal because options can change across different versions of the platform and it is better to rely on the system defaults if you don’t change a value. For example, I’ve edited this export down to:

```json
{
  "service": {
    "name": "data-science-engine",
    "cpus": 8,
    "mem": 51200,
    "gpu": {
      "enabled": true,
      "gpus": 1
    }
  }
}
```

You can edit this file to fit your needs or use the GUI to do so and download and edit the config.

### Installing the Data Science Engine Using the CLI

Now we can install the Data Science Engine package using the CLI:

```bash
dcos package install data-science-engine --options=./data-science-engine.json --yes	
```

### Complete Cluster/Service Automation Example

All together, that makes the entire process using the exported JSON package configuration:

```bash
# Boot DC/OS Cluster
terraform init -upgrade
terraform plan -var-file desired_cluster_profile.tfvars -out plan.out
terraform apply plan.out

# Get the cluster address from Terraform's JSON output
export CLUSTER_ADDRESS = `terraform output -json | jq -r '.["masters-ips"].value[0]'`

# Authenticate CLI to Cluster using its address and Install the Data Science Engine Package
dcos cluster setup http://$CLUSTER_ADDRESS # add whatever arguments you need for automated authentication
dcos package install data-science-engine --options=data-science-engine-options.json
```

## Conclusion
In this post we booted a DC/OS cluster and deployed the Data Science Engine in a repeatable manner, then executed a test notebook to create a Stack Overflow tagger.  This shows how PaaS can be used to enhance the productivity of a data science team.

Note: every step in the tutorial was rigorously tested, so please let me know in the comments if you run into any problems.

## Addendum: Common Errors

### `ssh-agent` Problems
If you forget to run the ssh-agent via `eval "$(ssh-agent -s)"` and then `ssh-add` your key, you will see the error below. This is especially easy to do if you open a new shell and run terraform commands from it. 

```bash
Error: Error applying plan:

1 error occurred:
	* module.dcos.module.dcos-install.module.dcos-install.null_resource.run_ansible_from_bootstrap_node_to_install_dcos: timeout - last error: ssh: handshake failed: ssh: unable to authenticate, attempted methods [none publickey], no supported methods remain
```

The solution is `ssh-add ./my_key` from the *paas_blog/dcos/terraform* directory. To avoid this in the future, you can edit the key field in *desired_cluster_profile.tfvars* to use a public key in your *~ /.ssh/* directory that you automatically add to the ssh-agent when the shell starts, using *~/.profile*, *~/.bash_profile* or *~/.bashrc*.

Now verify the key has been added:

```bash
ssh-add -l
```

Which should show:

```bash
2048 SHA256:1234567891234567891234567891234567891234567 ./my_key (RSA)
```

### Timeout Problems

Occasionally things don’t synchronize properly when DC/OS boots up and you’ll get an error about Ansible bootstrap or the load balancer timing out. The thing to do is to destroy and then plan/apply to recreate. It will work the second time.

If you see either of the following errors, this is what is going on.

```bash
Error: Error applying plan:

1 error occurred:
	* module.dcos.module.dcos-infrastructure.module.dcos-lb.module.dcos-lb-public-agents.module.public-agents.aws_lb.loadbalancer: 1 error occurred:
	* aws_lb.loadbalancer: timeout while waiting for state to become 'active' (last state: 'provisioning', timeout: 10m0s)
```

```bash
Error: Error applying plan:

1 error occurred:
	* module.dcos.module.dcos-install.module.dcos-install.null_resource.run_ansible_from_bootstrap_node_to_install_dcos: timeout - last error: dial tcp 34.221.233.243:22: i/o timeout
```