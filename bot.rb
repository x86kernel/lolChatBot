# -*- encoding: utf-8 -*-

require 'rubygems'
require 'xmpp4r/client'
require 'digest/sha1'
require 'net/http'
require 'uri'
require 'logger'
require 'timeout' 

def NormalStringConvert(body, temp) # 그냥 일반 귓속말에서의 전체말 다듬기
    str = body.split # 공백단위로 문자열을 짜르고 첫번째 명령어 삭제
    str.shift 

    for i in str
        temp += i + ' '
    end
    
    return temp.chop # 뒤에 공백제거
end

def ChannelStringConvert(body, temp) # 채널에서의 전체말 다듬기
        str = body.split  # 공백단위로 문자열을 짜르고 첫번째 명령어 삭제
        str.shift

        for i in str # 공백으로 나눠진거 싹다 합침 첫번째 명령어 제외
            temp += i + ' '
        end

        return temp.split(']')[0] # ']' 뒤에 이문자 삭제!
end

def ChannelStringConvert_With(body, temp)

    if body !~ /(!\[CDATA\[@.+$)/
        return 0
    end

    str = body.split

    for i in str
        temp += i + ' '
    end

    return temp.split(']')[0].split('[')[2]
end

def SendMessage(to, type, body, cl)
    msgToSend = Jabber::Message.new(to, body)
    msgToSend.set_type(type)

    cl.send msgToSend
end

file = File.open('log.txt', File::WRONLY | File::APPEND | File::CREAT)

logger = Logger.new(STDOUT)

logger.formatter = proc do |severity, datetime, progname, msg|
    "#{datetime}: #{severity} -- #{msg}\n"
end

logger.info("Logger initialized")

#linefile = File.new('lines.bot', 'r')

#lines = linefile.read.force_encoding("utf-8")

var = 0;
commandStatus = 0; # 0 is normal status , 1 is mirror status, 2 is channel join, 3 is channel exit
channelHash = 0;
JoinChannel = Array.new

Bot_StatusMessage = "<body><profileIcon>528</profileIcon><wins>489</wins><level>30</level><queueType>RANKED_SOLO_5x5</queueType><gameQueueType>NORMAL</gameQueueType><rankedLeagueName>FiorasHorde</rankedLeagueName><rankedLeagueDivision>Ⅰ</rankedLeagueDivision><rankedLeagueTier>DIAMOND</rankedLeagueTier><rankedWins>45</rankedWins><statusMsg>Status Message</statusMsg></body>"
Bot_CommandHelp = "@채널입장, @채널퇴장, @상주채널, @채널말하기, @따라해"
Bot_channelCommandHelp = "@주사위, @말해"

jid = Jabber::JID::new('ID@pvp.net')
password = 'AIR_PASSWORD'

cl = Jabber::Client::new(jid)
cl.use_ssl = 0


    
begin
    cl.connect('chat.kr.lol.riotgames.com', 5223)
rescue 
    logger.warn("Can't Connecting Server, Reconnect...")
    retry
end

begin
    cl.auth(password)
rescue
    logger.fatal("Can't Authroized (Wrong Password)")
end

logger.info("Connected Server")

cl.send(Jabber::Presence.new.set_show(:chat).set_status(Bot_StatusMessage))

logger.info("Status Message initialized")

msgToSend = Jabber::Message.new(nil, nil)

noticethread = Thread.new {
    logger.info("Auto Saying Session Start")
    while 1
        if JoinChannel[0] != nil
            for i in JoinChannel
                SendMessage(i, :groupchat, "@명령어 를 입력해보세요!" , cl)
            end
        end
        sleep 300
    end
}

mainthread = Thread.current 
cl.add_message_callback do |recvMsg|
        if recvMsg.type == :chat
            if commandStatus == 0
                if recvMsg.body == '@명령어'
                    SendMessage(recvMsg.from, recvMsg.type, Bot_CommandHelp, cl)

                elsif recvMsg.body =~ /(\@채널입장\s.+$)/
                    temp = String.new
                    channelName = String.new

                    channelName = NormalStringConvert(recvMsg.body, temp)

                    channelHash = Digest::SHA1.hexdigest channelName
                    chatjoin = Jabber::Presence.new
                    chatjoin.set_to('pu~' + channelHash + '@lvl.pvp.net')
                    chatjoin.set_status(Bot_StatusMessage)
                    chatjoin.set_priority(1)

                    JoinChannel.push('pu~' + "#{channelHash}" + '@lvl.pvp.net')

                    logger.info("Channel Joined(" + channelName + ")")

                    cl.send(chatjoin)
                elsif recvMsg.body =~ /(\@채널퇴장\s.+$)/
                    temp = String.new
                    channelName = String.new

                    channelName = NormalStringConvert(recvMsg.body, temp)

                    channelHash = Digest::SHA1.hexdigest channelName

                    Chatexit = Jabber::Presence.new
                    Chatexit.set_to('pu~' + channelHash + '@lvl.pvp.net')
                    Chatexit.set_type(:unavailable)

                    JoinChannel.delete('pu~' + "#{channelHash}" + '@lvl.pvp.net')
                
                    cl.send(Chatexit)

                elsif recvMsg.body == '@상주채널'
                    temp = String.new

                    for i in JoinChannel
                        temp += i + ", "
                    end

                    SendMessage(recvMsg.from, recvMsg.type, "#{temp}" , cl)
                elsif recvMsg.body == '@따라해'
                    commandStatus = 1
                elsif recvMsg.body == '@채널말하기'
                    commandStatus = 2

                    SendMessage(recvMsg.from, recvMsg.type, "채널이름 말하세요 그만해 라고 하면 그채널에서 그만말합니다.", cl)
                elsif recvMsg.body == '@주사위'
                    SendMessage(recvMsg.from, recvMsg.type, "#{1 + rand(100)}", cl)
                end # Normal status recvMsg.body check loop
            elsif commandStatus == 1 # mirror Status Check loop
                if recvMsg.body == '@그만해'
                    commandStatus = 0
                else
                    SendMessage(recvMsg.from, recvMsg.type, recvMsg.body, cl)
                end
            elsif commandStatus == 2
                channelHash = Digest::SHA1.hexdigest recvMsg.body
                
                commandStatus = 3
            elsif commandStatus == 3
                if recvMsg.body == '@그만해'
                    commandStatus = 0
                else
                    SendMessage("pu~" + channelHash + "@lvl.pvp.net", :groupchat, recvMsg.body, cl)
                end
            end # Other Status recvMsg.body check loop 
        elsif recvMsg.type == :groupchat
            temp = String.new
            mal = String.new

            people = "#{recvMsg.from}".split('/')[1] # 사용자 이름을 얻어옴
            mal = ChannelStringConvert_With(recvMsg.body, temp)
            channelName = "#{recvMsg.from}".gsub(/(\/.+)$/, '')

            if mal != 0
                if mal == '@명령어'
                    SendMessage(channelName, recvMsg.type, Bot_channelCommandHelp, cl)
                elsif mal == '@주사위'
                        SendMessage(channelName, recvMsg.type, people + "님의 주사위 : #{1 + rand(100)}", cl)

                elsif mal =~ /(^\@말해\s.+$)/
                    temp = String.new
                    mal = String.new
    
                    mal = ChannelStringConvert(recvMsg.body, temp)

                    SendMessage(channelName, recvMsg.type, "\"" + mal + "\" 라고 " + people + "님께서 말씀하셨어요!!", cl)
                elsif mal =~ /(^\@채널입장\s.+$)/
                    temp = String.new
                    channelName = String.new
    
                    channelName = ChannelStringConvert(recvMsg.body, temp)

                    channelHash = Digest::SHA1.hexdigest channelName
                    chatjoin = Jabber::Presence.new
                    chatjoin.set_to('pu~' + channelHash + '@lvl.pvp.net')
                    chatjoin.set_status(Bot_StatusMessage)
                    chatjoin.set_priority(1)

                    JoinChannel.push('pu~' + "#{channelHash}" + '@lvl.pvp.net')

                    logger.info("Channel Joined(" + channelName + ")" + " in Channel")
    
                    cl.send(chatjoin)
                end 
        end #other recvMsg.type Check loop
    end
end
Thread.stop  

cl.close

logger.closeq
