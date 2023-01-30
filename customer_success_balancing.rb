require 'minitest/autorun'
require 'timeout'

CustomerSuccessException = Struct.new(:input, :message)
CustomersException = Struct.new(:input, :message)

class CustomerSuccessBalancing
  include Comparable

  def initialize(customer_success, customers, away_customer_success)
    @customer_success = customer_success
    @customers = customers
    @away_customer_success = away_customer_success
  end

  # Returns the ID of the customer success with most customers
  def execute
    return exceptions if is_exceptions?

    define_available_customer_successes

    sort_by_score(@customer_success)

    balancing_clients_to_customer_successes

    result = customer_success_with_greater_service

    result.one? ? result[0][:id] : 0
  end

  private

  def define_available_customer_successes
    if @away_customer_success.any?
      @customer_success.reject! { |c| @away_customer_success.include?(c[:id]) }
    end
  end

  def sort_by_score(objects=[])
    objects.sort_by! { |obj| obj[:score] }
  end

  def balancing_clients_to_customer_successes
    @customer_success.each do |cs|
      cs[:meet_to_customers] = @customers.select { |c| c[:score].to_i <= cs[:score].to_i }
      @customers = @customers - cs[:meet_to_customers] if cs[:meet_to_customers].any?
    end
  end

  def customer_success_with_greater_service
    group_by_amount_of_customer_meet[1]
  end

  def group_by_amount_of_customer_meet
    @customer_success.group_by { |cs| cs[:meet_to_customers].count }.sort.last
  end

  def generate_exception(klass, input, message)
    klass.new(input, message)
  end

  def customer_success_exception(input, message="amount not allowed")
    generate_exception(CustomerSuccessException, input, message)
  end

  def customers_exception(input, message="amount not allowed")
    generate_exception(CustomersException, input, message)
  end

  def value_between(value, greater_then=1, less_then)
    value.between?(greater_then, less_then)
  end

  def exception_for_customer_success
    return :quantity unless value_between(@customer_success.count, 999)
    return :id unless @customer_success.map { |cs| value_between(cs[:id].to_i, 999) }.all?
    return :score unless @customer_success.map { |cs| value_between(cs[:score].to_i, 9_999) }.all?
    if @away_customer_success.count > (@customer_success.count / 2.0).floor
      :away_customer_success
    end
  end

  def exception_for_customers
    return :quantity unless value_between(@customers.count, 999_999)
    return :id unless @customers.map { |cs| value_between(cs[:id].to_i, 999_999) }.all?
    return :score unless @customers.map { |cs| value_between(cs[:score].to_i, 99_999) }.all?
  end

  def is_exception_for_customer_success?
    exception_for_customer_success
  end

  def is_exception_for_customers?
    exception_for_customers
  end

  def is_exceptions?
    is_exception_for_customer_success? || is_exception_for_customers?
  end

  def customer_success_exceptions
    case exception_for_customer_success
    when :quantity
      customer_success_exception(:quantity)
    when :id
      customer_success_exception(:id)
    when :score
      customer_success_exception(:score)
    when :away_customer_success
      customer_success_exception(:away_customer_success)
    end
  end

  def customers_exceptions
    case exception_for_customers
    when :quantity
      customers_exception(:quantity)
    when :id
      customers_exception(:id)
    when :score
      customers_exception(:score)
    end
  end

  def exceptions
    # note: sometimes repetition is better than a messy abstraction ;)
    return customer_success_exceptions if is_exception_for_customer_success?
    return customers_exceptions if is_exception_for_customers?
  end
end

class CustomerSuccessBalancingTests < Minitest::Test
  def test_scenario_one
    balancer = CustomerSuccessBalancing.new(
      build_scores([60, 20, 95, 75]),
      build_scores([90, 20, 70, 40, 60, 10]),
      [2, 4]
    )
    assert_equal 1, balancer.execute
  end

  def test_scenario_two
    balancer = CustomerSuccessBalancing.new(
      build_scores([11, 21, 31, 3, 4, 5]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      []
    )
    assert_equal 0, balancer.execute
  end

  def test_scenario_three
    balancer = CustomerSuccessBalancing.new(
      build_scores(Array(1..999)),
      build_scores(Array.new(10000, 998)),
      [999]
    )
    result = Timeout.timeout(1.0) { balancer.execute }
    assert_equal 998, result
  end

  def test_scenario_four
    balancer = CustomerSuccessBalancing.new(
      build_scores([1, 2, 3, 4, 5, 6]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      []
    )
    assert_equal 0, balancer.execute
  end

  def test_scenario_five
    balancer = CustomerSuccessBalancing.new(
      build_scores([100, 2, 3, 6, 4, 5]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      []
    )
    assert_equal 1, balancer.execute
  end

  def test_scenario_six
    balancer = CustomerSuccessBalancing.new(
      build_scores([100, 99, 88, 3, 4, 5]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      [1, 3, 2]
    )
    assert_equal 0, balancer.execute
  end

  def test_scenario_seven
    balancer = CustomerSuccessBalancing.new(
      build_scores([100, 99, 88, 3, 4, 5]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      [4, 5, 6]
    )
    assert_equal 3, balancer.execute
  end

  def test_scenario_eight
    balancer = CustomerSuccessBalancing.new(
      build_scores(Array(1..1000)),
      build_scores(Array.new(10000, 998)),
      []
    )

    result = balancer.execute

    assert_equal CustomerSuccessException, result.class
    assert_equal :quantity, result.input
    assert_equal "amount not allowed", result.message
  end

  def test_scenario_nine
    balancer = CustomerSuccessBalancing.new(
      [],
      build_scores(Array.new(10000, 998)),
      []
    )

    result = balancer.execute

    assert_equal CustomerSuccessException, result.class
    assert_equal :quantity, result.input
    assert_equal "amount not allowed", result.message
  end

  def test_scenario_ten
    balancer = CustomerSuccessBalancing.new(
      build_scores([11, 21, 31, 3, 4, 5]),
      build_scores(Array.new(1_000_000, 998)),
      []
    )

    result = balancer.execute

    assert_equal CustomersException, result.class
    assert_equal :quantity, result.input
    assert_equal "amount not allowed", result.message
  end

  def test_scenario_eleven
    balancer = CustomerSuccessBalancing.new(
      build_scores([11, 21, 31, 3, 4, 5]),
      [],
      []
    )

    result = balancer.execute

    assert_equal CustomersException, result.class
    assert_equal :quantity, result.input
    assert_equal "amount not allowed", result.message
  end

  def test_scenario_twelve
    balancer = CustomerSuccessBalancing.new(
      [{ id: 1000, score: 960 }],
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      []
    )

    result = balancer.execute

    assert_equal CustomerSuccessException, result.class
    assert_equal :id, result.input
    assert_equal "amount not allowed", result.message
  end

  def test_scenario_thirteen
    balancer = CustomerSuccessBalancing.new(
      [{ id: [0, nil, ""].sample, score: 960 }],
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      []
    )

    result = balancer.execute

    assert_equal CustomerSuccessException, result.class
    assert_equal :id, result.input
    assert_equal "amount not allowed", result.message
  end

  def test_scenario_fourteen
    balancer = CustomerSuccessBalancing.new(
      build_scores([11, 21, 31, 3, 4, 5]),
      [{ id: 1_000_000, score: 9600 }],
      []
    )

    result = balancer.execute

    assert_equal CustomersException, result.class
    assert_equal :id, result.input
    assert_equal "amount not allowed", result.message
  end

  def test_scenario_fifteen
    balancer = CustomerSuccessBalancing.new(
      build_scores([11, 21, 31, 3, 4, 5]),
      [{ id: [0, nil, ""].sample, score: 9600 }],
      []
    )

    result = balancer.execute

    assert_equal CustomersException, result.class
    assert_equal :id, result.input
    assert_equal "amount not allowed", result.message
  end

  def test_scenario_sixteen
    balancer = CustomerSuccessBalancing.new(
      [{ id: 960, score: 10_000 }],
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      []
    )

    result = balancer.execute

    assert_equal CustomerSuccessException, result.class
    assert_equal :score, result.input
    assert_equal "amount not allowed", result.message
  end

  def test_scenario_seventeen
    balancer = CustomerSuccessBalancing.new(
      [{ id: 960, score: [0, nil, ""].sample }],
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      []
    )

    result = balancer.execute

    assert_equal CustomerSuccessException, result.class
    assert_equal :score, result.input
    assert_equal "amount not allowed", result.message
  end

  def test_scenario_eighteen
    balancer = CustomerSuccessBalancing.new(
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      [{ id: 9920, score: 100_000 }],
      []
    )

    result = balancer.execute

    assert_equal CustomersException, result.class
    assert_equal :score, result.input
    assert_equal "amount not allowed", result.message
  end

  def test_scenario_nineteen
    balancer = CustomerSuccessBalancing.new(
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      [{ id: 9920, score: [0, nil, ""].sample }],
      []
    )

    result = balancer.execute

    assert_equal CustomersException, result.class
    assert_equal :score, result.input
    assert_equal "amount not allowed", result.message
  end

  def test_scenario_twenty
    balancer = CustomerSuccessBalancing.new(
      [{ id: 920, score: "9600" }],
      build_scores([11, 21, 31, 3, 4, 5]),
      []
    )

    assert_equal 920, balancer.execute
  end

  def test_scenario_twenty_one
    balancer = CustomerSuccessBalancing.new(
      [{ id: 920, score: "9600" }],
      [{ id: 899_220, score: "99600" }],
      []
    )

    assert_equal 920, balancer.execute
  end

  def test_scenario_twenty_two
    balancer = CustomerSuccessBalancing.new(
      build_scores([60, 20, 95, 75]),
      build_scores([90, 20, 70, 40, 60, 10]),
      [2, 3, 4]
    )

    result = balancer.execute

    assert_equal CustomerSuccessException, result.class
    assert_equal :away_customer_success, result.input
    assert_equal "amount not allowed", result.message
  end

  private

  def build_scores(scores)
    scores.map.with_index do |score, index|
      { id: index + 1, score: score }
    end
  end
end
