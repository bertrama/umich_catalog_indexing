FROM jruby:9

RUN apt-get update && \
    apt-get install -y gcc --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir /app /data
WORKDIR /app
COPY Gemfile* /app/
RUN bundle install
COPY . /app

ARG READER=alephsequential
ARG WRITER=localhost
ARG TDIR=/app
ARG SOLR_URL=http://catalog-solr:8025/solr/biblio
ARG DATADIR=/data

ENV SOLR_URL=${SOLR_URL} \
    TDIR=${TDIR} \
    READER=${READER} \
    WRITER=${WRITER} \
    DATADIR=${DATADIR}

CMD bin/index-data-dir ${DATADIR}
#CMD bundle exec traject \
#  -c $TDIR/readers/$READER.rb \
#  -c $TDIR/writers/$WRITER.rb \
#  -c $TDIR/indexers/common.rb \
#  -c $TDIR/indexers/common_ht.rb \
#  -c $TDIR/indexers/umich.rb \
#  -s log.file=STDOUT \
#  $filename \
