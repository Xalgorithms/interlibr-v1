#Compile and Run - Generic
echo
echo "[info] [cnr] Compiling and running rules."

#Location of XA-Rules
loc_rule_compiler="/home/rflec028/xalgo/xa-rules/"

#Location of Test Runs
loc_test_run="/home/rflec028/xalgo/rules-interpreter/test-runs/"

#Location of Rule Interpreter
loc_interpreter="/home/rflec028/xalgo/rules-interpreter/"

#Name of Rule Package
name_rule="issue11-while"

#Concatenate paths:
rule_location="$loc_test_run$name_rule/*.rule"
rule_json_location="$loc_test_run$name_rule/*.rule.json"

eval "rm $rule_json_location"
cd "$loc_rule_compiler"

for rule in $rule_location; do
  echo "[info] [cnr] Compiling $rule"
  json="$rule.json"
  bundle exec ruby cli.rb $rule $json
done

 
echo "[info] [cnr] Compiled rules. Running..."
cd "$loc_interpreter"
sbt "runMain org.xalgorithms.rules.Runner test-runs/$name_rule/"
echo "[info] [cnr] Done."
