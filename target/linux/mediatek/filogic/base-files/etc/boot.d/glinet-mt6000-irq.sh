#!/bin/sh

set +e

mod_param() {
	[ -d "/sys/module/$1" ] || return
	[ -d "/sys/module/$1/parameters" ] || return
	cat "/sys/module/$1/parameters/$2"
}

_nproc() {
	cat /proc/cpuinfo | grep -Ec '^processor\s*:' || echo 1
}
nproc=$(_nproc)

f_phys_irq=$(( nproc + 3 ))
irq_phys_to_virt() {
	awk "\$1 ~ /^[0-9]+:\$/ && \$${f_phys_irq} == \"$1\" {sub(\":\",\"\",\$1); print \$1 ; exit ; }" < /proc/interrupts
}

eth_irq_tx=229
eth_irq_rx=230

wed_enable=$(mod_param mt7915e wed_enable)
case "${wed_enable}" in
Y | 1 )
	wifi1_irq=237 ;;
* )
	wifi1_irq=245 ;;
esac

cpu=0
for irq in "$(irq_phys_to_virt ${eth_irq_tx})" "$(irq_phys_to_virt ${eth_irq_rx})" "$(irq_phys_to_virt ${wifi1_irq})" ; do
	[ -n "${irq}" ] || continue

	cpu=$((cpu+1))
	[ ${cpu} -lt ${nproc} ] || break

	f="/proc/irq/${irq}/smp_affinity_list"
	grep -EH -e '^' "$f" >&2
	echo ${cpu} > "$f"
	grep -EH -e '^' "$f" >&2
	echo >&2
done
