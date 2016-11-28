#!/bin/sh
set -e

# point /etc/hosts here to reject outgoing
REJECT_ADDR=127.1.1.1

echo --------------------------------------------------------------------------
echo Installing iptables rules.
echo --------------------------------------------------------------------------

#flush rules
iptables  -v --flush
iptables  -v --delete-chain
ip6tables -v --flush
ip6tables -v --delete-chain

#defaults
iptables  -v --policy OUTPUT  ACCEPT
ip6tables -v --policy OUTPUT  ACCEPT
iptables  -v --policy INPUT   DROP
ip6tables -v --policy INPUT   DROP
iptables  -v --policy FORWARD DROP
ip6tables -v --policy FORWARD DROP

iptables  -v --append OUTPUT -d $REJECT_ADDR -j REJECT


# ipv6 needs these to function correctly,
# -m hl --hl-eq 255 seems to be broken, why?
ip6tables -v --append INPUT  -p icmpv6 --icmpv6-type neighbor-solicitation  --jump ACCEPT
ip6tables -v --append INPUT  -p icmpv6 --icmpv6-type neighbor-advertisement --jump ACCEPT
ip6tables -v --append INPUT  -p icmpv6 --icmpv6-type router-advertisement --jump ACCEPT
ip6tables -v --append INPUT  -p icmpv6 --icmpv6-type redirect --jump ACCEPT


#ip6tables -v --append OUTPUT -p icmpv6 -j ACCEPT
# allow input from established connections
iptables  -v --append INPUT --match state --state ESTABLISHED,RELATED --jump ACCEPT
ip6tables -v --append INPUT --match state --state ESTABLISHED,RELATED --jump ACCEPT

# example incoming ssh
#iptables --append INPUT -p tcp -s 0/0 -d $HOST_IP --sport 513:65535 --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT


# just in case
iptables  -v --append OUTPUT  --jump ACCEPT
ip6tables -v --append OUTPUT  --jump ACCEPT
iptables  -v --append INPUT   --jump DROP
ip6tables -v --append INPUT   --jump DROP
iptables  -v --append FORWARD --jump DROP
ip6tables -v --append FORWARD --jump DROP
echo --------------------------------------------------------------------------
exit 0
