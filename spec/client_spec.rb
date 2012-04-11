require 'spec_helper'

module RedisFailover
  Client::Redis = RedisStub
  class ClientStub < Client
    def current_master
      @master
    end

    def current_slaves
      @slaves
    end

    def fetch_redis_servers
      {
        :master => 'localhost:6379',
        :slaves => ['localhost:1111'],
        :unreachable => []
      }
    end
  end

  describe Client do
    let(:client) { ClientStub.new(:host => 'localhost', :port => 3000) }

    describe '#build_clients' do
      it 'properly parses master' do
        client.current_master.to_s.should == 'localhost:6379'
      end

      it 'properly parses slaves' do
        client.current_slaves.first.to_s.should == 'localhost:1111'
      end
    end

    describe '#dispatch' do
      it 'routes write operations to master' do
        client.current_master.should_receive(:del)
        client.del('foo')
      end

      it 'routes read operations to a slave' do
        client.current_slaves.first.should_receive(:get)
        client.get('foo')
      end

      it 'reconnects with redis failover server when node is unreachable' do
        class << client
          attr_reader :reconnected
          def build_clients
            @reconnected = true
            super
          end
        end

        client.current_master.make_unreachable!
        client.del('foo')
        client.reconnected.should be_true
      end
    end
  end
end