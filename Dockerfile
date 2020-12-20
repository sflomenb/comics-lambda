FROM public.ecr.aws/lambda/python:3.8

RUN yum -y update \
    && yum -y install \
        cups-libs \
        dbus-glib \
        libXrandr \
        libXcursor \
        libXinerama \
        cairo \
        cairo-gobject \
        pango \
        libXcomposite \
        libXi \
        libXtst \
        libXScrnSaver \
        alsa-lib \
        atk \
        at-spi2-atk \
        gtk3 \
        gdk-pixbuf2

COPY requirements.txt /var/task/

RUN pip3 install -r requirements.txt

ENV PYPPETEER_HOME=/tmp

COPY comics.py /var/task

CMD [ "comics.lambda_handler" ]
