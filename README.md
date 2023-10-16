# Remote Caches For Reliable CI Builds
Are you a DevOps engineer who has gotten the dreaded "Uh, hey, my CI is too slow?".
Unfortunately, I am. I find the ideal length of a CI pipeline is 15 or less minutes, 
however, we tend to see them gradually grow and grow. This was especially true for
my teams because they utilize monorepos. As time went on, we added more services,
more test coverage, more docker images, more everything. The pipelines began to grow
to 30 or more minutes, which we began to deem as unacceptable in our fast paced
work environment.

Now, let's discuss some of the details of our system. It was collection of Java
and Python. The Java microservices were compiled and tested with Gradle. Both of 
the Python and Java microservices were then built in to docker images and published
to an internal registry.

## Our Example System
Let's take a walk through our system. We will have two services:

1. A Python FastAPI Service
2. A Java application which sends requests to our FastAPI service

Both of these services will be thrown into docker images and then will
be hosted with docker-compose.

Up to this portion, I will assume you have the following tools installed 
on your local machine:

1. Java
2. Python
3. Docker
4. Docker Compose

Now, to be clear, this isn't a tutorial on Java or Python, so I won't be
going through the code of these services in too much detail. However, I do
invite you to go through and take a look at the python and java applications
and feel free to tweak them!

## Take 1 - Our Naive Approach

In our naive approach, we will assume we have completely ephemeral CI agents. For example,
this may be your use case if you:

* Run Jenkins in Kubernetes or docker (EKS/GKE/etc.)
* Use GitHub actions without any of their caching mechanisms
* Use any stateless agents to perform your builds

So, if we were to walk through an example ci build, we might:

1. Download some source code for version control
2. Install plugins, dependencies, etc. for our monorepo
3. Build and assemble any compilable code
4. Run unit tests
5. Build docker images

And, without any type of remote cache, each step in the above would have
to start back from scratch. Let's simulate this on our local computer by wiping
caches between runs (utilizing the `gradlew clean` command).

### Cacheless Gradle Builds

Let us start by doing cacheless gradle builds:

```shell
prompt> time ./gradlew clean build

BUILD SUCCESSFUL in 10s
8 actionable tasks: 8 executed
./gradlew clean build  0.68s user 0.10s system 6% cpu 11.451 total
prompt> time ./gradlew clean build

BUILD SUCCESSFUL in 10s
8 actionable tasks: 8 executed
./gradlew clean build  0.68s user 0.10s system 6% cpu 11.443 total
prompt> time ./gradlew clean build

BUILD SUCCESSFUL in 10s
8 actionable tasks: 8 executed
./gradlew clean build  0.71s user 0.10s system 7% cpu 11.445 total
prompt> 
```

So, on average, it looks like we're seeing about 10s to build our java code.
In our case, this is because one of our tests takes a long time to execute.
In a cacheless world, this test would be run every single build, adding a good
chunk of time to each build.

Now, imagine if you had hundreds of tests and each one took a few hundred milliseconds.
It's not hard to imagine that this could grow from tens of seconds to tens of minutes 
(even for small code changes)!

### Cacheless Docker Builds
Let's do something similar with our docker images!

Let's see how long it takes our java image to build:
```shell
prompt> docker build . -t java-app                                
[+] Building 106.5s (13/13) FINISHED                                                                                                                                                 docker:desktop-linux
 => [internal] load .dockerignore                                                                                                                                                                    0.0s
 => => transferring context: 2B                                                                                                                                                                      0.0s
 => [internal] load build definition from Dockerfile                                                                                                                                                 0.0s
 => => transferring dockerfile: 326B                                                                                                                                                                 0.0s
 => [internal] load metadata for docker.io/library/openjdk:17-slim                                                                                                                                   1.5s
 => [internal] load metadata for docker.io/library/gradle:8.2.1-jdk17                                                                                                                                1.5s
 => [internal] load build context                                                                                                                                                                    0.1s
 => => transferring context: 6.36MB                                                                                                                                                                  0.0s
 => [build 1/4] FROM docker.io/library/gradle:8.2.1-jdk17@sha256:16ef1894635126ef2040faa8c042c479b992b5167a976be7a2dc82e389712a94                                                                   84.9s
 => => resolve docker.io/library/gradle:8.2.1-jdk17@sha256:16ef1894635126ef2040faa8c042c479b992b5167a976be7a2dc82e389712a94                                                                          0.0s
 => => sha256:b95af475fe5c7e9636ca685e4befe199114a7c8b2077a3b8049dcb254c20a824 2.21kB / 2.21kB                                                                                                       0.0s
 => => sha256:0f279b84e49ef3d508662430da4c9dd7be63fe8056f91480ad726dc0a0026d45 10.44kB / 10.44kB                                                                                                     0.0s
 => => sha256:16ef1894635126ef2040faa8c042c479b992b5167a976be7a2dc82e389712a94 1.21kB / 1.21kB                                                                                                       0.0s
 => => sha256:9ea365e1e52efb9567c56f02f2200f0e95ddffd579225cc5b20a6333119d2811 28.39MB / 28.39MB                                                                                                    13.9s
 => => sha256:1c321f4fb81c9a8d9170f2e66e24c105f438bac179a8c09632ea442be47ef6a3 18.86MB / 18.86MB                                                                                                    24.0s
 => => extracting sha256:9ea365e1e52efb9567c56f02f2200f0e95ddffd579225cc5b20a6333119d2811                                                                                                            0.9s
 => => sha256:3c00170ce19917ea14b85f4fa9825e11b4b74e380192404eafdf981c4df05ada 143.55MB / 143.55MB                                                                                                  66.4s
 => => extracting sha256:1c321f4fb81c9a8d9170f2e66e24c105f438bac179a8c09632ea442be47ef6a3                                                                                                            0.9s
 => => sha256:1414075e7edcb54ea8db49f693f01dceb960c31d1a8b9fd1d0985a1e3d5f14ea 172B / 172B                                                                                                          24.3s
 => => sha256:7bc086f9e3d9c4aa949f8fb5501b4e590f4dc111b091ad4037103964f04a4c75 734B / 734B                                                                                                          24.8s
 => => sha256:1f84d0f1f52eadf81e8f283a382ec357460927f977590c7e53708199ae807e51 4.37kB / 4.37kB                                                                                                      25.2s
 => => sha256:0c484970394358c05ab63b50addda4d962150411fb692e285effeb3bbae0f5da 51.13MB / 51.13MB                                                                                                    48.6s
 => => sha256:55efcf73c3a86067b96cb99a2d5a4af9dd35ec3141e08995d618aebafc0a75bb 128.73MB / 128.73MB                                                                                                  84.2s
 => => extracting sha256:3c00170ce19917ea14b85f4fa9825e11b4b74e380192404eafdf981c4df05ada                                                                                                            1.2s
 => => sha256:38099e256360fd98a53134abee0e7fff30bf160fd5a5ea9fab14afa516c50f0a 172B / 172B                                                                                                          67.4s
 => => extracting sha256:1414075e7edcb54ea8db49f693f01dceb960c31d1a8b9fd1d0985a1e3d5f14ea                                                                                                            0.0s
 => => extracting sha256:7bc086f9e3d9c4aa949f8fb5501b4e590f4dc111b091ad4037103964f04a4c75                                                                                                            0.0s
 => => extracting sha256:1f84d0f1f52eadf81e8f283a382ec357460927f977590c7e53708199ae807e51                                                                                                            0.0s
 => => extracting sha256:0c484970394358c05ab63b50addda4d962150411fb692e285effeb3bbae0f5da                                                                                                            2.0s
 => => extracting sha256:55efcf73c3a86067b96cb99a2d5a4af9dd35ec3141e08995d618aebafc0a75bb                                                                                                            0.6s
 => => extracting sha256:38099e256360fd98a53134abee0e7fff30bf160fd5a5ea9fab14afa516c50f0a                                                                                                            0.0s
 => [stage-1 1/3] FROM docker.io/library/openjdk:17-slim@sha256:aaa3b3cb27e3e520b8f116863d0580c438ed55ecfa0bc126b41f68c3f62f9774                                                                    75.3s
 => => resolve docker.io/library/openjdk:17-slim@sha256:aaa3b3cb27e3e520b8f116863d0580c438ed55ecfa0bc126b41f68c3f62f9774                                                                             0.0s
 => => sha256:aaa3b3cb27e3e520b8f116863d0580c438ed55ecfa0bc126b41f68c3f62f9774 547B / 547B                                                                                                           0.0s
 => => sha256:d732b25fa8a6944d312476805d086aeaaa6c9e2fbc3aefd482b819d5e0e32e10 953B / 953B                                                                                                           0.0s
 => => sha256:8a3a2ffec52aef5b3f650bb129502816675eac3d3518be13de8673a274288079 4.81kB / 4.81kB                                                                                                       0.0s
 => => sha256:6d4a449ac69c579312443ded09f57c4894e7adb42f7406abd364f95982fafc59 30.07MB / 30.07MB                                                                                                    13.6s
 => => sha256:a59f13dc084e185af417a4c6d1be2534adaff0c4f35ac2166a539260f4e8e945 1.36MB / 1.36MB                                                                                                       0.5s
 => => sha256:1d5035d2d5c6c24e610a9317c6907a7c58efd512757d559841e5d0851512ed9c 186.53MB / 186.53MB                                                                                                  73.9s
 => => extracting sha256:6d4a449ac69c579312443ded09f57c4894e7adb42f7406abd364f95982fafc59                                                                                                            1.3s
 => => extracting sha256:a59f13dc084e185af417a4c6d1be2534adaff0c4f35ac2166a539260f4e8e945                                                                                                            0.1s
 => => extracting sha256:1d5035d2d5c6c24e610a9317c6907a7c58efd512757d559841e5d0851512ed9c                                                                                                            1.3s
 => [stage-1 2/3] RUN mkdir /app                                                                                                                                                                     0.2s
 => [build 2/4] COPY --chown=gradle:gradle . /home/gradle/src                                                                                                                                        0.1s
 => [build 3/4] WORKDIR /home/gradle/src                                                                                                                                                             0.0s
 => [build 4/4] RUN gradle build --no-daemon                                                                                                                                                        20.0s
 => [stage-1 3/3] COPY --from=build /home/gradle/src/app/build/libs/app.jar /app/app.jar                                                                                                             0.0s
 => exporting to image                                                                                                                                                                               0.0s
 => => exporting layers                                                                                                                                                                              0.0s
 => => writing image sha256:a8ceea779f8724241d87076030e121dd92ae707516922edcf3b7508cb4e206f5                                                                                                         0.0s
 => => naming to docker.io/library/java-app                                                                                                                                                          0.0s

What's Next?
  View a summary of image vulnerabilities and recommendations → docker scout quickview

prompt> docker system prune -a -f &> /dev/null
```

And our python image:

```shell
[+] Building 30.3s (11/11) FINISHED                                                                                                                                                  docker:desktop-linux
 => [internal] load build definition from Dockerfile                                                                                                                                                 0.0s
 => => transferring dockerfile: 393B                                                                                                                                                                 0.0s
 => [internal] load .dockerignore                                                                                                                                                                    0.0s
 => => transferring context: 2B                                                                                                                                                                      0.0s
 => [internal] load metadata for docker.io/library/python:3.9-slim                                                                                                                                   1.6s
 => [1/6] FROM docker.io/library/python:3.9-slim@sha256:d99e43ea163609b2af59d8ce07771dbb12c4b0d77b2c3c836261128ab0ac7394                                                                             8.1s
 => => resolve docker.io/library/python:3.9-slim@sha256:d99e43ea163609b2af59d8ce07771dbb12c4b0d77b2c3c836261128ab0ac7394                                                                             0.0s
 => => sha256:d99e43ea163609b2af59d8ce07771dbb12c4b0d77b2c3c836261128ab0ac7394 1.86kB / 1.86kB                                                                                                       0.0s
 => => sha256:d7b7fc556af2573670e3c96b56ab4c3b72375de30de5601134246b294783ad43 1.37kB / 1.37kB                                                                                                       0.0s
 => => sha256:872b0e766abc378e40800cb619e33997de046741a9124a749f0978d806d305ac 6.93kB / 6.93kB                                                                                                       0.0s
 => => sha256:1bc163a14ea6a886d1d0f9a9be878b1ffd08a9311e15861137ccd85bb87190f9 29.18MB / 29.18MB                                                                                                     6.3s
 => => sha256:5f658eaeb6f6b3d1c7e64402784a96941bb104650e33f18675d8a9aea28cfab2 3.33MB / 3.33MB                                                                                                       1.7s
 => => sha256:28c1359943e158a8168c0f2adc68fe6d4fbcf1c8737ec7d91e2fdfa136409f15 11.86MB / 11.86MB                                                                                                     3.5s
 => => sha256:c3e4a5be6abeb571ec7611a475caf2d6083f43d1963b90d8caabda748427ad91 243B / 243B                                                                                                           2.0s
 => => sha256:5737be20a845a0c5a17dccc4bcb42078c09a14bf00552863d3f583ee1a1d9ebd 3.13MB / 3.13MB                                                                                                       3.5s
 => => extracting sha256:1bc163a14ea6a886d1d0f9a9be878b1ffd08a9311e15861137ccd85bb87190f9                                                                                                            1.0s
 => => extracting sha256:5f658eaeb6f6b3d1c7e64402784a96941bb104650e33f18675d8a9aea28cfab2                                                                                                            0.1s
 => => extracting sha256:28c1359943e158a8168c0f2adc68fe6d4fbcf1c8737ec7d91e2fdfa136409f15                                                                                                            0.4s
 => => extracting sha256:c3e4a5be6abeb571ec7611a475caf2d6083f43d1963b90d8caabda748427ad91                                                                                                            0.0s
 => => extracting sha256:5737be20a845a0c5a17dccc4bcb42078c09a14bf00552863d3f583ee1a1d9ebd                                                                                                            0.2s
 => [internal] load build context                                                                                                                                                                    0.0s
 => => transferring context: 42.90kB                                                                                                                                                                 0.0s
 => [2/6] RUN mkdir /app                                                                                                                                                                             0.2s
 => [3/6] WORKDIR /app                                                                                                                                                                               0.0s
 => [4/6] COPY poetry.lock pyproject.toml /app/                                                                                                                                                      0.0s
 => [5/6] RUN pip install poetry==1.6.1 &&     poetry export -f requirements.txt -o requirements.txt --without-hashes &&     pip install -r requirements.txt &&     rm -f requirements.txt          20.0s
 => [6/6] COPY python_app/ /app/                                                                                                                                                                     0.0s 
 => exporting to image                                                                                                                                                                               0.3s 
 => => exporting layers                                                                                                                                                                              0.3s 
 => => writing image sha256:4d2a6e1e3cf8eb80efe3d73a60e5a088c06261e72d1183a6278851ff73d28687                                                                                                         0.0s 
 => => naming to docker.io/library/python-app                                                                                                                                                        0.0s 
                                                                                                                                                                                                          
What's Next?
  View a summary of image vulnerabilities and recommendations → docker scout quickview

prompt> docker system prune -a -f &> /dev/null

prompt> docker build . -t python-app
[+] Building 37.5s (11/11) FINISHED                                                                                                                                                  docker:desktop-linux
 => [internal] load .dockerignore                                                                                                                                                                    0.0s
 => => transferring context: 2B                                                                                                                                                                      0.0s
 => [internal] load build definition from Dockerfile                                                                                                                                                 0.0s
 => => transferring dockerfile: 393B                                                                                                                                                                 0.0s
 => [internal] load metadata for docker.io/library/python:3.9-slim                                                                                                                                   1.3s
 => [1/6] FROM docker.io/library/python:3.9-slim@sha256:d99e43ea163609b2af59d8ce07771dbb12c4b0d77b2c3c836261128ab0ac7394                                                                             8.5s
 => => resolve docker.io/library/python:3.9-slim@sha256:d99e43ea163609b2af59d8ce07771dbb12c4b0d77b2c3c836261128ab0ac7394                                                                             0.0s
 => => sha256:d99e43ea163609b2af59d8ce07771dbb12c4b0d77b2c3c836261128ab0ac7394 1.86kB / 1.86kB                                                                                                       0.0s
 => => sha256:d7b7fc556af2573670e3c96b56ab4c3b72375de30de5601134246b294783ad43 1.37kB / 1.37kB                                                                                                       0.0s
 => => sha256:872b0e766abc378e40800cb619e33997de046741a9124a749f0978d806d305ac 6.93kB / 6.93kB                                                                                                       0.0s
 => => sha256:1bc163a14ea6a886d1d0f9a9be878b1ffd08a9311e15861137ccd85bb87190f9 29.18MB / 29.18MB                                                                                                     6.6s
 => => sha256:5f658eaeb6f6b3d1c7e64402784a96941bb104650e33f18675d8a9aea28cfab2 3.33MB / 3.33MB                                                                                                       1.3s
 => => sha256:28c1359943e158a8168c0f2adc68fe6d4fbcf1c8737ec7d91e2fdfa136409f15 11.86MB / 11.86MB                                                                                                     3.7s
 => => sha256:c3e4a5be6abeb571ec7611a475caf2d6083f43d1963b90d8caabda748427ad91 243B / 243B                                                                                                           1.6s
 => => sha256:5737be20a845a0c5a17dccc4bcb42078c09a14bf00552863d3f583ee1a1d9ebd 3.13MB / 3.13MB                                                                                                       2.6s
 => => extracting sha256:1bc163a14ea6a886d1d0f9a9be878b1ffd08a9311e15861137ccd85bb87190f9                                                                                                            1.0s
 => => extracting sha256:5f658eaeb6f6b3d1c7e64402784a96941bb104650e33f18675d8a9aea28cfab2                                                                                                            0.1s
 => => extracting sha256:28c1359943e158a8168c0f2adc68fe6d4fbcf1c8737ec7d91e2fdfa136409f15                                                                                                            0.4s
 => => extracting sha256:c3e4a5be6abeb571ec7611a475caf2d6083f43d1963b90d8caabda748427ad91                                                                                                            0.0s
 => => extracting sha256:5737be20a845a0c5a17dccc4bcb42078c09a14bf00552863d3f583ee1a1d9ebd                                                                                                            0.2s
 => [internal] load build context                                                                                                                                                                    0.0s
 => => transferring context: 42.90kB                                                                                                                                                                 0.0s
 => [2/6] RUN mkdir /app                                                                                                                                                                             0.2s
 => [3/6] WORKDIR /app                                                                                                                                                                               0.0s
 => [4/6] COPY poetry.lock pyproject.toml /app/                                                                                                                                                      0.0s
 => [5/6] RUN pip install poetry==1.6.1 &&     poetry export -f requirements.txt -o requirements.txt --without-hashes &&     pip install -r requirements.txt &&     rm -f requirements.txt          27.1s
 => [6/6] COPY python_app/ /app/                                                                                                                                                                     0.0s
 => exporting to image                                                                                                                                                                               0.3s
 => => exporting layers                                                                                                                                                                              0.3s
 => => writing image sha256:cda5734bd735b5003d0ded3417f6987fa2c6ab2a9b0892dfe2057c536bf4fc0f                                                                                                         0.0s 
 => => naming to docker.io/library/python-app                                                                                                                                                        0.0s 
                                                                                                                                                                                                          
What's Next?
  View a summary of image vulnerabilities and recommendations → docker scout quickview
```

So, on average, it looks like our java app takes more than 100 seconds to build and our python
image takes over 30 seconds to build. Again, this seems super high, right? Especially if
a developer is just making minor changes, like adding a log statement or similar. Is 
there any way we can trim this down?

## Take 2 - Remote Caches To The Rescue

So, now we will look into remote caching between our builds with 
the following resources:

1. [Gradle S3 Remote Cache Plugin](https://github.com/burrunan/gradle-s3-build-cache)
2. [Docker S3 Remote Cache Backend](https://docs.docker.com/build/cache/backends/s3/)

We will use a single S3 bucket to store all of our caches. For creation of an S3 bucket,
please refer to the [AWS Documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/create-bucket-overview.html).
There is also some terraform included in this blogs associated [GitHub repo]() 
if that's more your flavor.

So, from a high level, what will happen in each of these cases?

For the gradle caching, it will push whatever would be in your `.gradle/` directory
into S3. Next time you run a build, whether on your laptop, your buddies laptop, 
or a CI server, it will download that `.gradle/` and calculate the changes that occurred.
Then, it will build and test only what it needs to.

The docker caching will work in a similar way! All of your layers and manifests will
be stored in S3 as blob objects instead of locally on your laptop. The process moving
forward is similar to the gradle caching: download the layers and manifests, calculate
any changes, and pickup from where the cache left off.

### Cached Gradle Builds

Let us try out our gradle builds with a remote cache, and its SUPER easy
to configure. All you need to do is open up your `settings.gradle` and add
a few lines:

```groovy
// Download and apply the plugin
plugins {
  id("com.github.burrunan.s3-build-cache") version "1.5"
}

apply plugin: 'com.github.burrunan.s3-build-cache'

// Search the environment to see if this is a CI server
// Some users might not want people pushing to a remote
// cache if its shared, however, you can easily override 
// this
ext.isCiServer = System.getenv().containsKey("IS_CI")

buildCache {
    local {
        // If this is a CI server, we want to push to 
        // remote, so we can disable our local cache
        enabled = !isCiServer
    }
    remote(com.github.burrunan.s3cache.AwsS3BuildCache) {
        // Now, we can configure the gradle plugin to tell
        // it where to look for our bucket. I prefer to use
        // environment variables here so that I can switch it
        // to a new bucket without making source code changes
        region = System.getenv("CACHE_REGION")
        bucket = System.getenv("CACHE_BUCKET")
        // Personally, I like to group my caches so that different
        // users or different builds don't step on each other's toes
        prefix = 'gradlecache/' + System.getenv("CACHE_PREFIX") + "-cache/"
        push = isCiServer
        sessionToken = ''
        lookupDefaultAwsCredentials = false
    }
}
```
The above code block will tell gradle a few things:

1. Disable your local cache, instead use a remote cache
2. Look in AWS, at the `<CACHE_REGION>` region, for a bucket named `<CACHE_BUCKET>`
3. Download any relevant caches under the `gradlecache/<CACHE_PREFIX>-cache` prefix
4. Compute any differences, run your build
5. Write our cache updates under the `gradlecache/<CACHE_PREFIX>-cache` prefix

Let's try a few runs with our remote cache:

```shell
prompt> export IS_CI=true
prompt> export CACHE_REGION=us-east-1
prompt> export CACHE_BUCKET=afoleydevops-caches
prompt> export S3_BUILD_CACHE_ACCESS_KEY_ID=your-access-key
prompt> export S3_BUILD_CACHE_SECRET_KEY="your-access-secret"
prompt> export CACHE_PREFIX=local

prompt> ./gradlew clean build

BUILD SUCCESSFUL in 12s
8 actionable tasks: 7 executed, 1 up-to-date
S3 cache 650ms wasted on misses, reads: 3, elapsed: 650ms
S3 cache writes: 3, elapsed: 1021ms, sent to cache: 11 KiB
prompt> ./gradlew clean build

BUILD SUCCESSFUL in 1s
8 actionable tasks: 5 executed, 3 from cache
S3 cache 677ms wasted on hits, hits: 3, elapsed: 652ms, received: 11 KiB
prompt> ./gradlew clean build

BUILD SUCCESSFUL in 1s
8 actionable tasks: 5 executed, 3 from cache
S3 cache 696ms wasted on hits, hits: 3, elapsed: 674ms, received: 11 KiB
prompt> 
```

Wow! Look at that improvememt. We ran the same test each time 
(`gradle clean build`), just like we did in the uncached version. Gradle
was smart enough not to run those long tests again (because nothing changed)
even though we cleaned the build cache each time. Because of this, we
went from about 10 seconds per build to 1 second per build after the cache was
populated. We can look in AWS as well to see the data in the build cache:


### Cached Docker Builds

We saw that we got a huge improvement from our gradle remote caching,
let's see if theres a way to do the same thing with our docker images.
Revisiting the above, it took between 100 and 115 seconds to build
our java application and about 30 to 40 seconds to build our python 
application. Let's see if we can beat that...

First, we will need to create a new buildx context so that we can leverage
the s3 remote cache. Note that not all contexts support the remote caches
as described [here](). Luckily, making a new one is super easy:

```shell
prompt> docker buildx create --use --driver=docker-container --name ci-env
```

Now, because our context is using the `docker-container` driver, we can leverage
a remote S3 cache.

```shell
prompt> docker buildx build -t java-app \
  --cache-to type=s3,access_key_id=$S3_BUILD_CACHE_ACCESS_KEY_ID,secret_access_key=$S3_BUILD_CACHE_SECRET_KEY,region=$CACHE_REGION,bucket=$CACHE_BUCKET,name=dockercache/$CACHE_PREFIX/java-app,blobs_prefix=dockercache/$CACHE_PREFIX/java-app/ \
  --cache-from type=s3,access_key_id=$S3_BUILD_CACHE_ACCESS_KEY_ID,secret_access_key=$S3_BUILD_CACHE_SECRET_KEY,region=$CACHE_REGION,bucket=$CACHE_BUCKET,name=dockercache/$CACHE_PREFIX/java-app,blobs_prefix=dockercache/$CACHE_PREFIX/java-app/ \
  --load \
  .
[+] Building 184.2s (17/17) FINISHED                                                                                                                                              docker-container:ci-env
 => [internal] booting buildkit                                                                                                                                                                      1.6s
 => => pulling image moby/buildkit:buildx-stable-1                                                                                                                                                   1.2s
 => => creating container buildx_buildkit_ci-env0                                                                                                                                                    0.4s
 => [internal] load build definition from Dockerfile                                                                                                                                                 0.0s
 => => transferring dockerfile: 352B                                                                                                                                                                 0.0s
 => [internal] load metadata for docker.io/library/openjdk:17-slim                                                                                                                                   1.4s
 => [internal] load metadata for docker.io/library/gradle:8.2.1-jdk17                                                                                                                                1.5s
 => [internal] load .dockerignore                                                                                                                                                                    0.0s
 => => transferring context: 2B                                                                                                                                                                      0.0s
 => importing cache manifest from s3:8008674313398514530                                                                                                                                             0.5s
 => [internal] load build context                                                                                                                                                                    0.1s
 => => transferring context: 6.32MB                                                                                                                                                                  0.1s
 => [stage-1 1/3] FROM docker.io/library/openjdk:17-slim@sha256:aaa3b3cb27e3e520b8f116863d0580c438ed55ecfa0bc126b41f68c3f62f9774                                                                   110.6s
 => => resolve docker.io/library/openjdk:17-slim@sha256:aaa3b3cb27e3e520b8f116863d0580c438ed55ecfa0bc126b41f68c3f62f9774                                                                             0.0s
 => => sha256:1d5035d2d5c6c24e610a9317c6907a7c58efd512757d559841e5d0851512ed9c 186.53MB / 186.53MB                                                                                                 109.4s
 => => sha256:a59f13dc084e185af417a4c6d1be2534adaff0c4f35ac2166a539260f4e8e945 1.36MB / 1.36MB                                                                                                       0.6s
 => => sha256:6d4a449ac69c579312443ded09f57c4894e7adb42f7406abd364f95982fafc59 30.07MB / 30.07MB                                                                                                    19.8s
 => => extracting sha256:6d4a449ac69c579312443ded09f57c4894e7adb42f7406abd364f95982fafc59                                                                                                            0.5s
 => => extracting sha256:a59f13dc084e185af417a4c6d1be2534adaff0c4f35ac2166a539260f4e8e945                                                                                                            0.0s
 => => extracting sha256:1d5035d2d5c6c24e610a9317c6907a7c58efd512757d559841e5d0851512ed9c                                                                                                            1.1s
 => [build 1/4] FROM docker.io/library/gradle:8.2.1-jdk17@sha256:16ef1894635126ef2040faa8c042c479b992b5167a976be7a2dc82e389712a94                                                                  120.3s
 => => resolve docker.io/library/gradle:8.2.1-jdk17@sha256:16ef1894635126ef2040faa8c042c479b992b5167a976be7a2dc82e389712a94                                                                          0.0s
 => => sha256:38099e256360fd98a53134abee0e7fff30bf160fd5a5ea9fab14afa516c50f0a 172B / 172B                                                                                                           0.3s
 => => sha256:55efcf73c3a86067b96cb99a2d5a4af9dd35ec3141e08995d618aebafc0a75bb 128.73MB / 128.73MB                                                                                                  75.4s
 => => sha256:1f84d0f1f52eadf81e8f283a382ec357460927f977590c7e53708199ae807e51 4.37kB / 4.37kB                                                                                                       0.2s
 => => sha256:7bc086f9e3d9c4aa949f8fb5501b4e590f4dc111b091ad4037103964f04a4c75 734B / 734B                                                                                                           0.2s
 => => sha256:0c484970394358c05ab63b50addda4d962150411fb692e285effeb3bbae0f5da 51.13MB / 51.13MB                                                                                                    31.6s
 => => sha256:1414075e7edcb54ea8db49f693f01dceb960c31d1a8b9fd1d0985a1e3d5f14ea 172B / 172B                                                                                                           0.4s
 => => sha256:1c321f4fb81c9a8d9170f2e66e24c105f438bac179a8c09632ea442be47ef6a3 18.86MB / 18.86MB                                                                                                    13.4s
 => => sha256:3c00170ce19917ea14b85f4fa9825e11b4b74e380192404eafdf981c4df05ada 143.55MB / 143.55MB                                                                                                  85.4s
 => => sha256:9ea365e1e52efb9567c56f02f2200f0e95ddffd579225cc5b20a6333119d2811 28.39MB / 28.39MB                                                                                                    16.7s
 => => extracting sha256:9ea365e1e52efb9567c56f02f2200f0e95ddffd579225cc5b20a6333119d2811                                                                                                            0.4s
 => => extracting sha256:1c321f4fb81c9a8d9170f2e66e24c105f438bac179a8c09632ea442be47ef6a3                                                                                                            0.4s
 => => extracting sha256:3c00170ce19917ea14b85f4fa9825e11b4b74e380192404eafdf981c4df05ada                                                                                                            1.0s
 => => extracting sha256:1414075e7edcb54ea8db49f693f01dceb960c31d1a8b9fd1d0985a1e3d5f14ea                                                                                                            0.0s
 => => extracting sha256:7bc086f9e3d9c4aa949f8fb5501b4e590f4dc111b091ad4037103964f04a4c75                                                                                                            0.0s
 => => extracting sha256:1f84d0f1f52eadf81e8f283a382ec357460927f977590c7e53708199ae807e51                                                                                                            0.0s
 => => extracting sha256:0c484970394358c05ab63b50addda4d962150411fb692e285effeb3bbae0f5da                                                                                                            0.8s
 => => extracting sha256:55efcf73c3a86067b96cb99a2d5a4af9dd35ec3141e08995d618aebafc0a75bb                                                                                                            0.6s
 => => extracting sha256:38099e256360fd98a53134abee0e7fff30bf160fd5a5ea9fab14afa516c50f0a                                                                                                            0.0s
 => [stage-1 2/3] RUN mkdir /app                                                                                                                                                                     0.2s
 => [build 2/4] COPY --chown=gradle:gradle . /home/gradle/src                                                                                                                                        0.3s
 => [build 3/4] WORKDIR /home/gradle/src                                                                                                                                                             0.0s
 => [build 4/4] RUN gradle build --no-daemon -Dorg.gradle.caching=false                                                                                                                             30.0s
 => [stage-1 3/3] COPY --from=build /home/gradle/src/app/build/libs/app.jar /app/app.jar                                                                                                             0.0s
 => exporting to docker image format                                                                                                                                                                 4.8s
 => => exporting layers                                                                                                                                                                              0.0s
 => => exporting manifest sha256:d5706e2ff0d3d8a09d1d4539c473313ea345ff744f9e9603124359406518db5e                                                                                                    0.0s
 => => exporting config sha256:87f907088ca42c8b26d1df56f9f1f51a24976eec7ddcccec6897bba14999afa3                                                                                                      0.0s
 => => sending tarball                                                                                                                                                                               4.8s
 => importing to docker                                                                                                                                                                              2.6s
 => exporting cache to Amazon S3                                                                                                                                                                    24.9s
 => => preparing build cache for export                                                                                                                                                             24.9s
 => => writing layer sha256:1d5035d2d5c6c24e610a9317c6907a7c58efd512757d559841e5d0851512ed9c                                                                                                        18.8s
 => => writing layer sha256:254bc5bf306db0242d3425d8b36aa3067f6cfb15b3aed48d4b5db90f05aad588                                                                                                         0.2s
 => => writing layer sha256:36a0d3c30503ea67fd95d3601f4cdc20375827c22515ce67b83c12af6bf1ae52                                                                                                         0.1s
 => => writing layer sha256:6d4a449ac69c579312443ded09f57c4894e7adb42f7406abd364f95982fafc59                                                                                                         4.2s
 => => writing layer sha256:a59f13dc084e185af417a4c6d1be2534adaff0c4f35ac2166a539260f4e8e945                                                                                                         0.6s
prompt> docker buildx rm ci-env                                           
ci-env removed
prompt> docker buildx create --use --driver=docker-container --name ci-env
prompt> docker buildx build -t java-app \                                
  --cache-to type=s3,access_key_id=$S3_BUILD_CACHE_ACCESS_KEY_ID,secret_access_key=$S3_BUILD_CACHE_SECRET_KEY,region=$CACHE_REGION,bucket=$CACHE_BUCKET,name=dockercache/$CACHE_PREFIX/java-app,blobs_prefix=dockercache/$CACHE_PREFIX/java-app/ \
  --cache-from type=s3,access_key_id=$S3_BUILD_CACHE_ACCESS_KEY_ID,secret_access_key=$S3_BUILD_CACHE_SECRET_KEY,region=$CACHE_REGION,bucket=$CACHE_BUCKET,name=dockercache/$CACHE_PREFIX/java-app,blobs_prefix=dockercache/$CACHE_PREFIX/java-app/ \
  --load \
  .
[+] Building 115.9s (17/17) FINISHED                                                                                                                                              docker-container:ci-env
 => [internal] booting buildkit                                                                                                                                                                      1.6s
 => => pulling image moby/buildkit:buildx-stable-1                                                                                                                                                   1.2s
 => => creating container buildx_buildkit_ci-env0                                                                                                                                                    0.4s
 => [internal] load build definition from Dockerfile                                                                                                                                                 0.0s
 => => transferring dockerfile: 352B                                                                                                                                                                 0.0s
 => [internal] load metadata for docker.io/library/openjdk:17-slim                                                                                                                                   1.4s
 => [internal] load metadata for docker.io/library/gradle:8.2.1-jdk17                                                                                                                                1.4s
 => [internal] load .dockerignore                                                                                                                                                                    0.0s
 => => transferring context: 2B                                                                                                                                                                      0.0s
 => importing cache manifest from s3:8008674313398514530                                                                                                                                             0.4s
 => [internal] load build context                                                                                                                                                                    0.1s
 => => transferring context: 6.32MB                                                                                                                                                                  0.1s
 => [stage-1 1/3] FROM docker.io/library/openjdk:17-slim@sha256:aaa3b3cb27e3e520b8f116863d0580c438ed55ecfa0bc126b41f68c3f62f9774                                                                     0.0s
 => => resolve docker.io/library/openjdk:17-slim@sha256:aaa3b3cb27e3e520b8f116863d0580c438ed55ecfa0bc126b41f68c3f62f9774                                                                             0.0s
 => [build 1/4] FROM docker.io/library/gradle:8.2.1-jdk17@sha256:16ef1894635126ef2040faa8c042c479b992b5167a976be7a2dc82e389712a94                                                                    0.0s
 => => resolve docker.io/library/gradle:8.2.1-jdk17@sha256:16ef1894635126ef2040faa8c042c479b992b5167a976be7a2dc82e389712a94                                                                          0.0s
 => CACHED [stage-1 2/3] RUN mkdir /app                                                                                                                                                              0.0s
 => CACHED [build 2/4] COPY --chown=gradle:gradle . /home/gradle/src                                                                                                                                 0.0s
 => CACHED [build 3/4] WORKDIR /home/gradle/src                                                                                                                                                      0.0s
 => CACHED [build 4/4] RUN gradle build --no-daemon -Dorg.gradle.caching=false                                                                                                                       0.0s
 => [stage-1 3/3] COPY --from=build /home/gradle/src/app/build/libs/app.jar /app/app.jar                                                                                                           109.3s
 => => sha256:36a0d3c30503ea67fd95d3601f4cdc20375827c22515ce67b83c12af6bf1ae52 1.55kB / 1.55kB                                                                                                       0.1s
 => => sha256:1d5035d2d5c6c24e610a9317c6907a7c58efd512757d559841e5d0851512ed9c 186.53MB / 186.53MB                                                                                                 109.3s
 => => sha256:254bc5bf306db0242d3425d8b36aa3067f6cfb15b3aed48d4b5db90f05aad588 93B / 93B                                                                                                             0.4s
 => => sha256:a59f13dc084e185af417a4c6d1be2534adaff0c4f35ac2166a539260f4e8e945 1.36MB / 1.36MB                                                                                                       1.2s
 => => sha256:6d4a449ac69c579312443ded09f57c4894e7adb42f7406abd364f95982fafc59 30.07MB / 30.07MB                                                                                                    24.7s
 => exporting to docker image format                                                                                                                                                               111.4s
 => => exporting layers                                                                                                                                                                              0.0s
 => => exporting manifest sha256:d5706e2ff0d3d8a09d1d4539c473313ea345ff744f9e9603124359406518db5e                                                                                                    0.0s
 => => exporting config sha256:87f907088ca42c8b26d1df56f9f1f51a24976eec7ddcccec6897bba14999afa3                                                                                                      0.0s
 => => sending tarball                                                                                                                                                                               2.1s
 => importing to docker                                                                                                                                                                              0.0s
 => exporting cache to Amazon S3                                                                                                                                                                     0.8s
 => => preparing build cache for export                                                                                                                                                              0.8s
```

And the python one...

```shell
prompt> docker buildx build -t python-app \
  --cache-to type=s3,access_key_id=$S3_BUILD_CACHE_ACCESS_KEY_ID,secret_access_key=$S3_BUILD_CACHE_SECRET_KEY,region=$CACHE_REGION,bucket=$CACHE_BUCKET,name=dockercache/$CACHE_PREFIX/python-app,blobs_prefix=dockercache/$CACHE_PREFIX/python-app/ \
  --cache-from type=s3,access_key_id=$S3_BUILD_CACHE_ACCESS_KEY_ID,secret_access_key=$S3_BUILD_CACHE_SECRET_KEY,region=$CACHE_REGION,bucket=$CACHE_BUCKET,name=dockercache/$CACHE_PREFIX/python-app,blobs_prefix=dockercache/$CACHE_PREFIX/python-app/ \
  --load \
  .
[+] Building 56.1s (15/15) FINISHED                                                                                                                                               docker-container:ci-env
 => [internal] booting buildkit                                                                                                                                                                      2.5s
 => => pulling image moby/buildkit:buildx-stable-1                                                                                                                                                   2.2s
 => => creating container buildx_buildkit_ci-env0                                                                                                                                                    0.3s
 => [internal] load build definition from Dockerfile                                                                                                                                                 0.0s
 => => transferring dockerfile: 393B                                                                                                                                                                 0.0s
 => [internal] load metadata for docker.io/library/python:3.9-slim                                                                                                                                   2.7s
 => [internal] load .dockerignore                                                                                                                                                                    0.0s
 => => transferring context: 2B                                                                                                                                                                      0.0s
 => importing cache manifest from s3:18255539662270506446                                                                                                                                            0.6s
 => [1/6] FROM docker.io/library/python:3.9-slim@sha256:d99e43ea163609b2af59d8ce07771dbb12c4b0d77b2c3c836261128ab0ac7394                                                                             9.3s
 => => resolve docker.io/library/python:3.9-slim@sha256:d99e43ea163609b2af59d8ce07771dbb12c4b0d77b2c3c836261128ab0ac7394                                                                             0.0s
 => => sha256:c3e4a5be6abeb571ec7611a475caf2d6083f43d1963b90d8caabda748427ad91 243B / 243B                                                                                                           0.1s
 => => sha256:5737be20a845a0c5a17dccc4bcb42078c09a14bf00552863d3f583ee1a1d9ebd 3.13MB / 3.13MB                                                                                                       6.2s
 => => sha256:28c1359943e158a8168c0f2adc68fe6d4fbcf1c8737ec7d91e2fdfa136409f15 11.86MB / 11.86MB                                                                                                     7.2s
 => => sha256:5f658eaeb6f6b3d1c7e64402784a96941bb104650e33f18675d8a9aea28cfab2 3.33MB / 3.33MB                                                                                                       6.2s
 => => sha256:1bc163a14ea6a886d1d0f9a9be878b1ffd08a9311e15861137ccd85bb87190f9 29.18MB / 29.18MB                                                                                                     8.3s
 => => extracting sha256:1bc163a14ea6a886d1d0f9a9be878b1ffd08a9311e15861137ccd85bb87190f9                                                                                                            0.5s
 => => extracting sha256:5f658eaeb6f6b3d1c7e64402784a96941bb104650e33f18675d8a9aea28cfab2                                                                                                            0.1s
 => => extracting sha256:28c1359943e158a8168c0f2adc68fe6d4fbcf1c8737ec7d91e2fdfa136409f15                                                                                                            0.2s
 => => extracting sha256:c3e4a5be6abeb571ec7611a475caf2d6083f43d1963b90d8caabda748427ad91                                                                                                            0.0s
 => => extracting sha256:5737be20a845a0c5a17dccc4bcb42078c09a14bf00552863d3f583ee1a1d9ebd                                                                                                            0.1s
 => [internal] load build context                                                                                                                                                                    0.1s
 => => transferring context: 42.90kB                                                                                                                                                                 0.0s
 => [2/6] RUN mkdir /app                                                                                                                                                                             0.1s
 => [3/6] WORKDIR /app                                                                                                                                                                               0.0s
 => [4/6] COPY poetry.lock pyproject.toml /app/                                                                                                                                                      0.0s
 => [5/6] RUN pip install poetry==1.6.1 &&     poetry export -f requirements.txt -o requirements.txt --without-hashes &&     pip install -r requirements.txt &&     rm -f requirements.txt          24.8s
 => [6/6] COPY python_app/ /app/                                                                                                                                                                     0.0s
 => exporting to docker image format                                                                                                                                                                 4.2s
 => => exporting layers                                                                                                                                                                              2.0s
 => => exporting manifest sha256:3c73b42068387c2a87475733a03cd9c50ed13843ccebc9d311ebe0a3e2cf4003                                                                                                    0.0s 
 => => exporting config sha256:a16a03050617359db96fc313b13f0b027f0bce0dbe913a5e97473eef8bd312d8                                                                                                      0.0s 
 => => sending tarball                                                                                                                                                                               2.2s 
 => importing to docker                                                                                                                                                                              1.3s
 => exporting cache to Amazon S3                                                                                                                                                                    11.6s
 => => preparing build cache for export                                                                                                                                                             11.6s
 => => writing layer sha256:1bc163a14ea6a886d1d0f9a9be878b1ffd08a9311e15861137ccd85bb87190f9                                                                                                         3.2s
 => => writing layer sha256:28c1359943e158a8168c0f2adc68fe6d4fbcf1c8737ec7d91e2fdfa136409f15                                                                                                         1.5s
 => => writing layer sha256:45d410bced6bccf84b94c1e09e9e6d0b349f3ff0335f21a14e71357a974a0fb1                                                                                                         0.1s
 => => writing layer sha256:4f4fb700ef54461cfa02571ae0db9a0dc1e0cdb5577484a6d75e68dc38e8acc1                                                                                                         0.1s
 => => writing layer sha256:5737be20a845a0c5a17dccc4bcb42078c09a14bf00552863d3f583ee1a1d9ebd                                                                                                         0.6s
 => => writing layer sha256:5f658eaeb6f6b3d1c7e64402784a96941bb104650e33f18675d8a9aea28cfab2                                                                                                         0.7s
 => => writing layer sha256:69d9ca29597fdf4231432ea1d4161bc4248b8ecfb575a3f06207e20035fc6bc3                                                                                                         3.7s
 => => writing layer sha256:6f5aed9c13ee697a5132c311f72261125ae28d8fe2eb72304f08642cffe3b067                                                                                                         0.1s
 => => writing layer sha256:7d1f0bc1d40d387b5498dc56d4efcafc3c875673bb914abe7deca9384306d665                                                                                                         0.1s
 => => writing layer sha256:c3e4a5be6abeb571ec7611a475caf2d6083f43d1963b90d8caabda748427ad91                                                                                                         0.1s
prompt> docker buildx rm ci-env                                           
ci-env removed
prompt> docker buildx create --use --driver=docker-container --name ci-env
ci-env
prompt> docker buildx build -t python-app \                               
  --cache-to type=s3,access_key_id=$S3_BUILD_CACHE_ACCESS_KEY_ID,secret_access_key=$S3_BUILD_CACHE_SECRET_KEY,region=$CACHE_REGION,bucket=$CACHE_BUCKET,name=dockercache/$CACHE_PREFIX/python-app,blobs_prefix=dockercache/$CACHE_PREFIX/python-app/ \
  --cache-from type=s3,access_key_id=$S3_BUILD_CACHE_ACCESS_KEY_ID,secret_access_key=$S3_BUILD_CACHE_SECRET_KEY,region=$CACHE_REGION,bucket=$CACHE_BUCKET,name=dockercache/$CACHE_PREFIX/python-app,blobs_prefix=dockercache/$CACHE_PREFIX/python-app/ \
  --load \
  .
[+] Building 18.9s (15/15) FINISHED                                                                                                                                               docker-container:ci-env
 => [internal] booting buildkit                                                                                                                                                                      1.5s
 => => pulling image moby/buildkit:buildx-stable-1                                                                                                                                                   1.2s
 => => creating container buildx_buildkit_ci-env0                                                                                                                                                    0.4s
 => [internal] load build definition from Dockerfile                                                                                                                                                 0.0s
 => => transferring dockerfile: 393B                                                                                                                                                                 0.0s
 => [internal] load metadata for docker.io/library/python:3.9-slim                                                                                                                                   1.5s
 => [internal] load .dockerignore                                                                                                                                                                    0.0s
 => => transferring context: 2B                                                                                                                                                                      0.0s
 => importing cache manifest from s3:18255539662270506446                                                                                                                                            0.4s
 => [internal] load build context                                                                                                                                                                    0.0s
 => => transferring context: 42.90kB                                                                                                                                                                 0.0s
 => [1/6] FROM docker.io/library/python:3.9-slim@sha256:d99e43ea163609b2af59d8ce07771dbb12c4b0d77b2c3c836261128ab0ac7394                                                                             0.0s
 => => resolve docker.io/library/python:3.9-slim@sha256:d99e43ea163609b2af59d8ce07771dbb12c4b0d77b2c3c836261128ab0ac7394                                                                             0.0s
 => CACHED [2/6] RUN mkdir /app                                                                                                                                                                      0.0s
 => CACHED [3/6] WORKDIR /app                                                                                                                                                                        0.0s
 => CACHED [4/6] COPY poetry.lock pyproject.toml /app/                                                                                                                                               0.0s
 => CACHED [5/6] RUN pip install poetry==1.6.1 &&     poetry export -f requirements.txt -o requirements.txt --without-hashes &&     pip install -r requirements.txt &&     rm -f requirements.txt    0.0s
 => [6/6] COPY python_app/ /app/                                                                                                                                                                    13.1s
 => => sha256:7d1f0bc1d40d387b5498dc56d4efcafc3c875673bb914abe7deca9384306d665 256B / 256B                                                                                                           0.1s
 => => sha256:6f5aed9c13ee697a5132c311f72261125ae28d8fe2eb72304f08642cffe3b067 93B / 93B                                                                                                             0.2s
 => => sha256:5737be20a845a0c5a17dccc4bcb42078c09a14bf00552863d3f583ee1a1d9ebd 3.13MB / 3.13MB                                                                                                       4.0s
 => => sha256:4f4fb700ef54461cfa02571ae0db9a0dc1e0cdb5577484a6d75e68dc38e8acc1 32B / 32B                                                                                                             0.3s
 => => sha256:c3e4a5be6abeb571ec7611a475caf2d6083f43d1963b90d8caabda748427ad91 243B / 243B                                                                                                           0.3s
 => => sha256:45d410bced6bccf84b94c1e09e9e6d0b349f3ff0335f21a14e71357a974a0fb1 12.63kB / 12.63kB                                                                                                     0.3s
 => => sha256:69d9ca29597fdf4231432ea1d4161bc4248b8ecfb575a3f06207e20035fc6bc3 42.48MB / 42.48MB                                                                                                    12.7s
 => => sha256:5f658eaeb6f6b3d1c7e64402784a96941bb104650e33f18675d8a9aea28cfab2 3.33MB / 3.33MB                                                                                                       4.0s
 => => sha256:28c1359943e158a8168c0f2adc68fe6d4fbcf1c8737ec7d91e2fdfa136409f15 11.86MB / 11.86MB                                                                                                     8.0s
 => => sha256:1bc163a14ea6a886d1d0f9a9be878b1ffd08a9311e15861137ccd85bb87190f9 29.18MB / 29.18MB                                                                                                     8.0s
 => exporting to docker image format                                                                                                                                                                13.9s
 => => exporting layers                                                                                                                                                                              0.0s
 => => exporting manifest sha256:3c73b42068387c2a87475733a03cd9c50ed13843ccebc9d311ebe0a3e2cf4003                                                                                                    0.0s
 => => exporting config sha256:a16a03050617359db96fc313b13f0b027f0bce0dbe913a5e97473eef8bd312d8                                                                                                      0.0s
 => => sending tarball                                                                                                                                                                               0.9s
 => importing to docker                                                                                                                                                                              0.0s
 => exporting cache to Amazon S3                                                                                                                                                                     1.2s
 => => preparing build cache for export                                                                                                                                                              1.2s
```

So first we build the image. On our first build, it seems to take longer to actually build the image. This
is because we need to populate the cache on S3 for further builds. Then, to simulate
a completely fresh environment, we remove our docker context and make a brand new one, so no
cache is present at all on the machine. We see that our subsequent builds were much faster than 
their previous builds. The longest part of this entire process, once cached, is actually the `--load`
flag which we will describe below. In a CI environment, I would recommend omitting that flag
or replacing it with the `--push` flag to push an image directly to your desired registry. Just for
giggles, let's omit the `--load` flag for both:

Java: 
```shell
prompt> docker buildx rm ci-env                                           
ci-env removed
prompt> docker buildx create --use --driver=docker-container --name ci-env
ci-env
prompt> docker buildx build -t java-app \                                 
  --cache-to type=s3,access_key_id=$S3_BUILD_CACHE_ACCESS_KEY_ID,secret_access_key=$S3_BUILD_CACHE_SECRET_KEY,region=$CACHE_REGION,bucket=$CACHE_BUCKET,name=dockercache/$CACHE_PREFIX/java-app,blobs_prefix=dockercache/$CACHE_PREFIX/java-app/ \
  --cache-from type=s3,access_key_id=$S3_BUILD_CACHE_ACCESS_KEY_ID,secret_access_key=$S3_BUILD_CACHE_SECRET_KEY,region=$CACHE_REGION,bucket=$CACHE_BUCKET,name=dockercache/$CACHE_PREFIX/java-app,blobs_prefix=dockercache/$CACHE_PREFIX/java-app/ \
  .
[+] Building 4.7s (15/15) FINISHED                                                                                                                                                docker-container:ci-env
 => [internal] booting buildkit                                                                                                                                                                      1.6s
 => => pulling image moby/buildkit:buildx-stable-1                                                                                                                                                   1.3s
 => => creating container buildx_buildkit_ci-env0                                                                                                                                                    0.4s
 => [internal] load build definition from Dockerfile                                                                                                                                                 0.0s
 => => transferring dockerfile: 352B                                                                                                                                                                 0.0s
 => [internal] load metadata for docker.io/library/openjdk:17-slim                                                                                                                                   1.6s
 => [internal] load metadata for docker.io/library/gradle:8.2.1-jdk17                                                                                                                                1.6s
 => [internal] load .dockerignore                                                                                                                                                                    0.0s
 => => transferring context: 2B                                                                                                                                                                      0.0s
 => importing cache manifest from s3:8008674313398514530                                                                                                                                             0.4s
 => [internal] load build context                                                                                                                                                                    0.1s
 => => transferring context: 6.32MB                                                                                                                                                                  0.1s
 => [build 1/4] FROM docker.io/library/gradle:8.2.1-jdk17@sha256:16ef1894635126ef2040faa8c042c479b992b5167a976be7a2dc82e389712a94                                                                    0.0s
 => => resolve docker.io/library/gradle:8.2.1-jdk17@sha256:16ef1894635126ef2040faa8c042c479b992b5167a976be7a2dc82e389712a94                                                                          0.0s
 => [stage-1 1/3] FROM docker.io/library/openjdk:17-slim@sha256:aaa3b3cb27e3e520b8f116863d0580c438ed55ecfa0bc126b41f68c3f62f9774                                                                     0.0s
 => => resolve docker.io/library/openjdk:17-slim@sha256:aaa3b3cb27e3e520b8f116863d0580c438ed55ecfa0bc126b41f68c3f62f9774                                                                             0.0s
 => CACHED [stage-1 2/3] RUN mkdir /app                                                                                                                                                              0.0s
 => CACHED [build 2/4] COPY --chown=gradle:gradle . /home/gradle/src                                                                                                                                 0.0s
 => CACHED [build 3/4] WORKDIR /home/gradle/src                                                                                                                                                      0.0s
 => CACHED [build 4/4] RUN gradle build --no-daemon -Dorg.gradle.caching=false                                                                                                                       0.0s
 => CACHED [stage-1 3/3] COPY --from=build /home/gradle/src/app/build/libs/app.jar /app/app.jar                                                                                                      0.0s
 => exporting cache to Amazon S3                                                                                                                                                                     0.7s
 => => preparing build cache for export                                                                                                                                                              0.7s
WARNING: No output specified with docker-container driver. Build result will only remain in the build cache. To push result image into registry use --push or to load image into docker use --load
```

Python: 
```shell
prompt> docker buildx rm ci-env                                           
ci-env removed
prompt> docker buildx create --use --driver=docker-container --name ci-env
ci-env
prompt> docker buildx build -t python-app \                               
  --cache-to type=s3,access_key_id=$S3_BUILD_CACHE_ACCESS_KEY_ID,secret_access_key=$S3_BUILD_CACHE_SECRET_KEY,region=$CACHE_REGION,bucket=$CACHE_BUCKET,name=dockercache/$CACHE_PREFIX/python-app,blobs_prefix=dockercache/$CACHE_PREFIX/python-app/ \
  --cache-from type=s3,access_key_id=$S3_BUILD_CACHE_ACCESS_KEY_ID,secret_access_key=$S3_BUILD_CACHE_SECRET_KEY,region=$CACHE_REGION,bucket=$CACHE_BUCKET,name=dockercache/$CACHE_PREFIX/python-app,blobs_prefix=dockercache/$CACHE_PREFIX/python-app/ \
  .
[+] Building 5.1s (13/13) FINISHED                                                                                                                                                docker-container:ci-env
 => [internal] booting buildkit                                                                                                                                                                      1.6s
 => => pulling image moby/buildkit:buildx-stable-1                                                                                                                                                   1.2s
 => => creating container buildx_buildkit_ci-env0                                                                                                                                                    0.4s
 => [internal] load build definition from Dockerfile                                                                                                                                                 0.0s
 => => transferring dockerfile: 393B                                                                                                                                                                 0.0s
 => [internal] load metadata for docker.io/library/python:3.9-slim                                                                                                                                   1.6s
 => [internal] load .dockerignore                                                                                                                                                                    0.0s
 => => transferring context: 2B                                                                                                                                                                      0.0s
 => importing cache manifest from s3:18255539662270506446                                                                                                                                            0.5s
 => [1/6] FROM docker.io/library/python:3.9-slim@sha256:d99e43ea163609b2af59d8ce07771dbb12c4b0d77b2c3c836261128ab0ac7394                                                                             0.0s
 => => resolve docker.io/library/python:3.9-slim@sha256:d99e43ea163609b2af59d8ce07771dbb12c4b0d77b2c3c836261128ab0ac7394                                                                             0.0s
 => [internal] load build context                                                                                                                                                                    0.0s
 => => transferring context: 42.90kB                                                                                                                                                                 0.0s
 => CACHED [2/6] RUN mkdir /app                                                                                                                                                                      0.0s
 => CACHED [3/6] WORKDIR /app                                                                                                                                                                        0.0s
 => CACHED [4/6] COPY poetry.lock pyproject.toml /app/                                                                                                                                               0.0s
 => CACHED [5/6] RUN pip install poetry==1.6.1 &&     poetry export -f requirements.txt -o requirements.txt --without-hashes &&     pip install -r requirements.txt &&     rm -f requirements.txt    0.0s
 => CACHED [6/6] COPY python_app/ /app/                                                                                                                                                              0.0s
 => exporting cache to Amazon S3                                                                                                                                                                     1.2s
 => => preparing build cache for export                                                                                                                                                              1.2s
WARNING: No output specified with docker-container driver. Build result will only remain in the build cache. To push result image into registry use --push or to load image into docker use --load
```

Wow! We got down from 130 seconds to 5 seconds for the java app and from 30 seconds to 5 seconds in the python app!

Let's break down the new flags we passed to `docker buildx build`:

* `--cache-to` - This tells where docker where to export your cache to
* `--cache-from` - This tells where docker where to export your cache from. It might be that you want
                   to import your cache from a certain branch, maybe `main` or `develop`, but you 
                   don't want to export your cache to this location unless it's a verified branch.
* `--load` - This tells docker to load the image from your 
            build context into your local docker daemon so you can run the image
            
## Other remote caches to investigate

There are some other amazing remote cache resources as well:

1. [Pants Build System Remote Caches](https://www.pantsbuild.org/docs/remote-caching-execution)
2. [Gradle HTTP Remote Caches](https://docs.gradle.org/current/dsl/org.gradle.caching.http.HttpBuildCache.html)
3. [Maven Remote Caches](https://maven.apache.org/extensions/maven-build-cache-extension/getting-started.html)
4. [Lerna Remote Caches](https://lerna.js.org/docs/features/share-your-cache)