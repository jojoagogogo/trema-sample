# -*- coding: utf-8 -*-

require "pp"
require "json"

class SimpleSlice < Controller

  periodic_timer_event :update_info, 3
  attr_accessor :bcast_mac

  def update_info
    conf_js = File.open("conf.js").read
    @conf = JSON.load(conf_js)
    pp @conf
  end

  def start
    update_info
    @bcast_mac = "ff:ff:ff:ff:ff:ff"
  end

  def packet_in datapath_id, message

    pp "[#{datapath_id}] packet-in => #{ExactMatch.from( message )}"
    
    src = message.macsa.to_s
    dest = message.macda.to_s

    if [src,dest].include? @bcast_mac
      actions = ActionOutput.new( OFPP_NORMAL )
    else
      is_group = false
      @conf["groups"].keys.sort.each do |key|
        group = @conf["groups"][key]
        # group search 
        if ((group.include? src.downcase)||(group.include? src.upcase)) &&
            ((group.include? dest.downcase)||(group.include? dest.upcase))
          is_group = true
          break;
        end
      end
      if is_group
        actions = ActionOutput.new( OFPP_NORMAL )
      else
        actions = nil
      end
    end  
    
    #----------------------------
    # Flow Mod
    #----------------------------
    send_flow_mod_add(
      datapath_id,
      :hard_timeout => @conf["hard_timeout"].to_i,
      :match => ExactMatch.from( message ),
      :actions => actions
    )
    #----------------------------
    # Packet Out 
    #----------------------------
    send_packet_out(
      datapath_id,
      :hard_timeout => @conf["hard_timeout"].to_i,
      :packet_in => message,
      :actions => actions,
      :zero_padding => true
    )
  end

  def flow_removed datapath_id, message
    info "[#{datapath_id}] Flow Removed => #{ message.match}"
  end
end
