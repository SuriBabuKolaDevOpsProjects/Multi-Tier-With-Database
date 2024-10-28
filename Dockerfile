FROM amazoncorretto:17-alpine-jdk
ENV App_Home=/usr/src/app
WORKDIR ${App_Home}
COPY target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT [ "java", "-jar", "app.jar" ]