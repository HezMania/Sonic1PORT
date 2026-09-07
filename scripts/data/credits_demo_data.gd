class_name CreditsDemoData
extends RefCounted

# Genesis controller bit masks used by MoveSonicInDemo.
const BTN_UP := 0x01
const BTN_DOWN := 0x02
const BTN_LEFT := 0x04
const BTN_RIGHT := 0x08
const BTN_B := 0x10
const BTN_C := 0x20
const BTN_A := 0x40
const BTN_START := 0x80

const DEMOS: Array = [
	{"name":"GHZ1","zone":0,"act":1,"start":"startpos/Credits Demos/ghz1 (Credits demo 1).bin","frames":540,"inputs":[[8,101],[40,10],[8,80],[40,41],[8,20],[40,10],[8,132],[40,17],[8,68],[40,23],[8,20],[40,22],[8,26],[40,7],[8,51],[40,28],[0,1],[0,1],[0,1],[0,1],[0,1],[0,1],[0,1]]},
	{"name":"MZ2","zone":2,"act":2,"start":"startpos/Credits Demos/mz2 (Credits demo).bin","frames":540,"inputs":[[0,9],[4,32],[0,11],[8,22],[40,32],[41,3],[40,5],[32,2],[0,5],[4,35],[0,21],[4,26],[0,9],[4,1],[36,8],[4,4],[0,30],[4,84],[0,8],[8,8],[0,105],[4,8],[0,125],[4,9],[36,15],[4,11],[0,29],[0,1],[0,1],[0,1],[0,1],[0,1]]},
	{"name":"SYZ3","zone":4,"act":3,"start":"startpos/Credits Demos/syz3 (Credits demo).bin","frames":540,"inputs":[[0,24],[8,48],[0,27],[8,29],[10,3],[2,10],[0,8],[4,28],[0,42],[2,76],[0,99],[2,75],[0,75],[32,9],[40,8],[41,35],[40,3],[32,2],[0,56],[0,1],[0,1],[0,1],[0,1],[0,1]]},
	{"name":"LZ3","zone":1,"act":3,"start":"startpos/Credits Demos/lz3 (Credits demo).bin","frames":510,"inputs":[[0,5],[8,132],[0,147],[2,10],[0,6],[2,9],[0,5],[2,3],[0,16],[32,7],[0,95],[32,7],[0,38],[2,11],[0,7],[2,9],[0,8],[2,6],[0,17],[32,7],[0,112],[0,1],[0,1],[0,1]]},
	{"name":"SLZ3","zone":3,"act":3,"start":"startpos/Credits Demos/slz3 (Credits demo).bin","frames":540,"inputs":[[0,9],[8,238],[0,13],[2,34],[0,165],[4,39],[36,7],[4,67],[36,2],[4,83],[0,1],[0,1],[0,1],[0,1],[0,1],[0,1]]},
	{"name":"SBZ1","zone":5,"act":1,"start":"startpos/Credits Demos/sbz1 (Credits demo).bin","frames":540,"inputs":[[0,38],[4,83],[0,38],[4,36],[0,232],[4,105],[0,14],[8,111],[0,1],[0,1],[0,1],[0,1],[0,1],[0,1],[0,1],[0,1]]},
	{"name":"SBZ2","zone":5,"act":2,"start":"startpos/Credits Demos/sbz2 (Credits demo).bin","frames":540,"inputs":[[0,7],[8,17],[0,117],[8,48],[40,28],[8,85],[10,7],[2,33],[0,97],[32,30],[40,21],[8,18],[0,10],[8,32],[0,4],[8,7],[10,8],[2,39],[0,49],[0,1],[0,1],[0,1],[0,1],[0,1]]},
	{"name":"GHZ1B","zone":0,"act":1,"start":"startpos/Credits Demos/ghz1 (Credits demo 2).bin","frames":540,"inputs":[[0,8],[8,256],[8,72],[0,195],[4,63],[0,19],[8,27],[9,1],[8,15],[0,2],[0,1],[0,1],[0,1],[0,1],[0,1],[0,1],[0,1],[0,1],[0,1],[0,1],[0,1],[0,1],[0,1],[0,1]]},
]
