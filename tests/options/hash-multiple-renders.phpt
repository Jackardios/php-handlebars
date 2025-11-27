--TEST--
Handlebars\Options::$hash - Multiple renders with same VM
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

$vm = new VM();
$vm->setHelpers($registry);

$template = '{{test "x" one="A" two="B"}}';

// First render
$result1 = $vm->render($template, []);
var_dump($result1);

// Second render - hash should still be available
$result2 = $vm->render($template, []);
var_dump($result2);

// Third render - hash should still be available
$result3 = $vm->render($template, []);
var_dump($result3);

// All results should be identical
var_dump($result1 === $result2 && $result2 === $result3);
--EXPECT--
string(5) "[A,B]"
string(5) "[A,B]"
string(5) "[A,B]"
bool(true)
