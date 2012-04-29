# encoding: utf-8
require "rubygems"
require 'active_support/core_ext/module/attribute_accessors'
require 'httparty'
require "nokogiri"

require "direct_payment"

module MoIP
    include HTTParty

    # URI para acessar o serviço
    mattr_accessor :uri
    @@uri = 'https://www.moip.com.br'

    # Token de autenticação
    mattr_accessor :token

    # Chave de acesso ao serviço
    mattr_accessor :key

    def self.setup
      yield self
    end

    # Status de retorno 
    STATUS = { 1 => "authorized", 2 => "started", 3 => "printed", 4 => "completed", 5 => "canceled", 6 => "analysing" }

    base_uri "#{self.uri}/ws/alpha"
    basic_auth self.token, self.key

    class << self
      # Envia uma instrução para pagamento único
      def checkout(attributes = {})
        full_data = peform_action!(:post, 'EnviarInstrucao/Unica', :body => DirectPayment.body(attributes))

        get_response!(full_data["EnviarInstrucaoUnicaResponse"]["Resposta"])
      end

      # Consulta dos dados das autorizações e pagamentos associados à Instrução
      def query(token)
        full_data = peform_action!(:get, "ConsultarInstrucao/#{token}")

        get_response!(full_data["ConsultarTokenResponse"]["RespostaConsultar"])
      end

      # Retorna a URL de acesso ao MoIP
      def moip_page(token)
        raise(StandardError, "É necessário informar um token para retornar os dados da transação") if token.nil?
        "#{self.uri}/Instrucao.do?token=#{token}"
      end

      # Monta o NASP
      def notification(params)
        notification = {}
        notification[:transaction_id] = params["id_transacao"]
        notification[:amount]         = params["valor"]
        notification[:status]         = STATUS[params["status_pagamento"].to_i]
        notification[:code]           = params["cod_moip"]
        notification[:payment_type]   = params["tipo_pagamento"]
        notification[:email]          = params["email_consumidor"]
        notification
      end

      private

      def peform_action!(action_name, url, options = {})
        response = self.send(action_name, url, options)
        raise(StandardError, "Ocorreu um erro ao chamar o webservice") if response.nil?
        response
      end

      def get_response!(data)
        raise(StandardError, data["Erro"]) if data["Status"] == "Falha"
        data
      end
    end
end
