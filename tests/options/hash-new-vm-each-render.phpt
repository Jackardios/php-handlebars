--TEST--
Handlebars\Options::$hash - New VM for each render
--SKIPIF--
<?php if( !extension_loaded('handlebars') ) die('skip '); ?>
--FILE--
<?php
use Handlebars\VM;
use Handlebars\DefaultRegistry;
use Handlebars\Options;

$registry = new DefaultRegistry();
$registry['test'] = function ($val, Options $options) {
    $one = $options->hash['one'] ?? '';
    $two = $options->hash['two'] ?? '';
    return "[$one,$two]";
};

$template = '{{test "x" one="A" two="B"}}';

// First VM
$vm1 = new VM();
$vm1->setHelpers($registry);
$result1 = $vm1->render($template, []);
var_dump($result1);

// Second VM - hash should be available
$vm2 = new VM();
$vm2->setHelpers($registry);
$result2 = $vm2->render($template, []);
var_dump($result2);

// Third VM - hash should be available
$vm3 = new VM();
$vm3->setHelpers($registry);
$result3 = $vm3->render($template, []);
var_dump($result3);

// All results should be identical
var_dump($result1 === $result2 && $result2 === $result3);
--EXPECT--
string(5) "[A,B]"
string(5) "[A,B]"
string(5) "[A,B]"
bool(true)
