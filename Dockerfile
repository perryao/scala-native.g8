FROM openjdk:8u121-jre-alpine as build
RUN echo "installing dependencies" && \
    apk --update add gc-dev clang musl-dev libc-dev build-base git && \
    apk add libunwind-dev --update-cache --repository http://nl.alpinelinux.org/alpine/edge/main

RUN git clone https://github.com/google/re2.git && cd re2 && \
    CXX=clang++ make && make install

ENV SBT_VERSION 0.13.13
ENV SBT_HOME /usr/local/sbt
ENV PATH ${PATH}:${SBT_HOME}/bin

# Install sbt
RUN echo "installing SBT $SBT_VERSION" && \
    apk add --no-cache --update bash wget && mkdir -p "$SBT_HOME" && \
    wget -qO - --no-check-certificate "https://dl.bintray.com/sbt/native-packages/sbt/$SBT_VERSION/sbt-$SBT_VERSION.tgz" | tar xz -C $SBT_HOME --strip-components=1 && \
    echo -ne "- with sbt $SBT_VERSION\n" >> /root/.built && \
    sbt sbtVersion

RUN mkdir -p /root/project-build/project
WORKDIR /root/project-build

ADD ./project/plugins.sbt project/
ADD ./project/build.properties project/
ADD build.sbt .

RUN sbt update

ADD . /root/project-build/

RUN sbt clean nativeLink && \
    mv ./target/scala-2.11/*-out ./project-build-out

# CMD ./project-build-out

FROM alpine:3.3
COPY --from=build \
   /usr/lib/libunwind.so.8 \
   /usr/lib/libunwind-x86_64.so.8 \
   /usr/lib/libgc.so.1 \
   /usr/lib/libstdc++.so.6 \
   /usr/lib/libgcc_s.so.1 \
   /usr/lib/
COPY --from=build \
   /usr/local/lib/libre2.so.0 \
   /usr/local/lib/libre2.so.0
COPY --from=build \
   /root/project-build/project-build-out .
CMD ["./project-build-out"]
