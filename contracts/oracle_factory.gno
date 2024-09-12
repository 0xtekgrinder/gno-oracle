package oracle_factory

import (
	"fmt"
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ownable"
)

var (
	instances avl.Tree // symbol -> instance
	balances avl.Tree // address -> balance
)

func New(dataType string, fee uint64, curators []std.Address) {
	caller := std.PrevRealm().Addr()
	NewWithAdmin(dataType, fee, curators, caller)
}

func NewWithAdmin(dataType string, fee uint64, curators []std.Address, admin std.Address) {
	uuid := fmt.Sprintf("%s-%s", admin.String(), dataType)
	exists := instances.Has(uuid)
	if exists {
		panic("already exists")
	}
	if len(curators) < 1 {
		panic("curators length must be at least 1")
	}

	instance := &instance{
		admin:  ownable.NewWithAddress(admin),
		curators: curators,
		fee: fee,
		data: avl.NewTree(),
	}
	instances.Set(dataType, instance)
}

type instance struct {
	admin  *ownable.Ownable
	curators []std.Address
	fee uint64
	data *avl.Tree
}

/**
 * Admin methods
 */

func SetCurators(uuid string, curators []std.Address) {
	instance := mustGetInstance(uuid)
	instance.admin.AssertCallerIsOwner()

	if len(curators) < 1 {
		panic("curators length must be at least 1")
	}
	instance.curators = curators
}

func SetFee(uuid string, fee uint64) {
	instance := mustGetInstance(uuid)
	instance.admin.AssertCallerIsOwner()
	instance.fee = fee
}

/**
 * Curators methods
 */

func SetData(uuid string, key string, value string) {
	instance := mustGetInstance(uuid)
	caller := std.PrevRealm().Addr()
	if !isCurator(instance, caller) {
		panic("caller is not a curator")
	}

	instance.data.Set(key, value)
}

/**
 * Public methods
 */

func GetData(uuid string, key string) string {
	instance := mustGetInstance(uuid)

	sentCoins := std.GetOrigSend()
	if len(sentCoins) != 1 {
        panic("Send only one type of coin")
    }
	sentAmount := uint64(sentCoins[0].Amount)
    if sentAmount != instance.fee {
        panic("Too few coins sent")
    }
	if sentCoins[0].Denom != "ugnot" {
		panic("Send only GNOT")
	}

	addBalance(uuid, instance.fee)

	value, exists := instance.data.Get(key)
	if !exists {
		panic("key does not exist")
	}
	return value.(string)
}

func GetFee(uuid string) uint64 {
	instance := mustGetInstance(uuid)
	return instance.fee
}

func GetCurators(uuid string) []std.Address {
	instance := mustGetInstance(uuid)
	return instance.curators
}

func GetAdmin(uuid string) std.Address {
	instance := mustGetInstance(uuid)
	return instance.admin.Owner()
}

func DistributeFees(uuid string) {
	instance := mustGetInstance(uuid)
	balance := mustGetBalance(uuid)

	lenth := len(instance.curators)
	for _, curator := range instance.curators {
		addBalance(curator.String(), balance / uint64(lenth))
	}
}

/**
 * Internal methods
 */

func mustGetInstance(uuid string) *instance {
	t, exists := instances.Get(uuid)
	if !exists {
		panic("token instance does not exist")
	}
	return t.(*instance)
}

func mustGetBalance(addr string) uint64 {
	balance, exists := balances.Get(addr)
	if !exists {
		panic("address has no balance")
	}
	return balance.(uint64)
}

func isCurator(instance *instance, caller std.Address) bool {
	for _, curator := range instance.curators {
		if curator == caller {
			return true
		}
	}
	return false
}

func addBalance(addr string, amount uint64) {
	balance := mustGetBalance(addr)
	balance = balance + amount
	balances.Set(addr, balance)
}